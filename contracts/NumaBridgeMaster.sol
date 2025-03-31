//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


//
import "./interfaces/INumaVault.sol";
import "./interfaces/INumaBridgeReceiver.sol";
import "./NumaOFTAdapter.sol";

// 
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// OApp imports
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// OFT imports
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";



/// @title NumaBridgeMaster 
contract NumaBridgeMaster is Ownable2Step, Pausable, INumaBridgeReceiver
{
    using OptionsBuilder for bytes;
    struct RateLimit {
        uint256 windowStart;
        uint256 usedVolume;
    }

    RateLimit public rateLimit;
    
    uint256 public windowDuration = 1 hours; // e.g., 1 hour = 3600 seconds 
    uint256 public maxVolume = 10 ether; // e.g., 10 rETH
    uint256 public maxVolumeTx = 10 ether; // e.g., 10 rETH






    INumaVault immutable vault;
    NumaOFTAdapter immutable numaAdapter;
    IERC20 immutable numa;
    IERC20 immutable lstToken;

    mapping(uint32 => bool) public whitelistedEndpoints;

    uint256 public constant MIN = 1000;
    event EndpointWhitelisted(uint32 indexed endpointId, bool whitelisted);

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }


    constructor(address _vaultAddress,address _adapterAddress,address _numaAddress,address _lstTokenAddress) 
    Ownable(msg.sender)
    {
        vault = INumaVault(_vaultAddress);
        numaAdapter = NumaOFTAdapter(_adapterAddress);
        numa = IERC20(_numaAddress);
        lstToken = IERC20(_lstTokenAddress);
        rateLimit.windowStart = block.timestamp; // Initialize window
         _pause();
    }
    
    modifier onlyWhitelisted(uint32 _dstChainId) {
        require(whitelistedEndpoints[_dstChainId], "Destination chain not whitelisted");
        _;
    }

    function setWhitelistedEndpoint(uint32 _endpointId, bool _whitelisted) external onlyOwner {
        whitelistedEndpoints[_endpointId] = _whitelisted;
        emit EndpointWhitelisted(_endpointId, _whitelisted);
    }


    /**
     * @dev pause bridge
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause bridge
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function updateLimits(uint256 _windowDuration, uint256 _maxVolume,uint _maxVolumeTx) external onlyOwner{
        windowDuration = _windowDuration;
        maxVolume = _maxVolume;
        maxVolumeTx = _maxVolumeTx;
    }

    function estimateFee(uint _inputAmount,address _receiver,
        uint32 _dstEid) external view returns (uint)
    {
        uint _numaOut = vault.lstToNuma(_inputAmount);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            _dstEid,
            addressToBytes32(_receiver),
            _numaOut,
            _numaOut,
            options,
            "", 
            ""
        );
        MessagingFee memory fee = numaAdapter.quoteSend(sendParam, false);
        return fee.nativeFee;
    }

    function buyAndBridge(
        uint _inputAmount,
        uint _minNumaAmount,
        address _receiver,
        uint32 _dstEid
    ) external payable whenNotPaused onlyWhitelisted(_dstEid) 
    returns (uint _numaOut) 
    
    {
        require(_inputAmount <= maxVolumeTx, "Bridge volume limit exceeded");
        uint256 currentTime = block.timestamp;

        // If current time is outside the current window, reset it
        if (currentTime >= rateLimit.windowStart + windowDuration) {
            rateLimit.windowStart = currentTime; // Start a new window
            rateLimit.usedVolume = 0; // Reset usage
        }

        // Check if the limit is exceeded
        require(rateLimit.usedVolume + _inputAmount <= maxVolume, "Bridge volume limit exceeded");

        // Update used volume
        rateLimit.usedVolume += _inputAmount;


        // lst approval needed 
        SafeERC20.safeTransferFrom(
            lstToken,
            msg.sender,
            address(this),
            _inputAmount);
        


      
        // buy numa
        lstToken.approve(address(vault), _inputAmount);
        _numaOut = vault.buy(_inputAmount,_minNumaAmount,address(this));
        // same MIN as vault, because we don't want a revert on destination chain
        require(_numaOut > MIN,"not enough to bridge");
        numa.approve(address(numaAdapter), _numaOut);
     
     
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            _dstEid,
            addressToBytes32(_receiver),
            _numaOut,
            _numaOut,
            options,
            "", 
            ""
        );

        MessagingFee memory fee = numaAdapter.quoteSend(sendParam, false);

        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = numaAdapter.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );

        //refund fees
        uint excess = msg.value - fee.nativeFee;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

     function onReceive(
        uint _numaAmount,
        uint _minLstAmount,
        address _receiver
       
    ) external  returns (uint)
    
    {
       
        require (msg.sender == address(numaAdapter), "Only OFT allowed");
        bool success = checkVaultTransactionSuccess(_numaAmount,_minLstAmount,_receiver);

        if (success)
        {
            // sell should not revert, we can execute it
            numa.approve(address(vault), _numaAmount);
            // catching reverts just in case
            try vault.sell(_numaAmount, _minLstAmount, _receiver) returns (uint256 lstOut) {
                return lstOut;  // Assign inside the success block
            } 
            catch Error(string memory reason) 
            {
                success = false;
            }
            catch Panic(uint errorCode) {
                success = false;
            }
            catch (bytes memory lowLevelData) {
                success = false;
            }
    
        }
        if (!success)
        {
            // sell should revert, just send the numa to _receiver
            SafeERC20.safeTransfer(
                numa,            
                _receiver,
                _numaAmount);
            return 0;
        }
        

    }
    function checkVaultTransactionSuccess( uint _numaAmount,
        uint _minLstAmount,
        address _receiver) public view returns (bool)
    {
        uint _lstOut = vault.numaToLst(_numaAmount);
        // should not happen as we won't use slippage on destination chain
        if (_lstOut < _minLstAmount)
        {
            return false;
        }
        if (_lstOut == 0)
        {
            return false;// no price
        }

        if (lstToken.balanceOf(address(vault)) < _lstOut)
        {          
            // vault does not have enough liquidity
            return false;
        }
        return true;
    }
}