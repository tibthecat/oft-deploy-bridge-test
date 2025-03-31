// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import "./interfaces/INumaBridgeReceiver.sol";

//
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { OFTCore,MessagingFee, MessagingReceipt,Origin} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {SendParam,OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";

// 
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NumaOFT is OFT,ERC20Burnable {

    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    INumaBridgeReceiver public numaBridgeSatelliteReceiver;
    mapping(address => bool) public allowedContracts;

    address public minter;

    event AllowedContractUpdated(address indexed contractAddress, bool allowed);
    event BridgeReceiverUpdated(address indexed contractAddress);
    event MinterUpdated(address indexed contractAddress);

    // Address type handling
    function bytes32ToAddress(bytes32 _bytes32Address) internal pure returns (address _address) {
        return address(uint160(uint(_bytes32Address)));
    }


    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}


      // Modifier to check if caller is allowed
    modifier onlyAllowed() {
        require(allowedContracts[msg.sender], "Not allowed to bridge");
        _;
    }

    // Admin function to update allowed contracts
    function setAllowedContract(address _contract, bool _allowed) external onlyOwner {
        allowedContracts[_contract] = _allowed;
        emit AllowedContractUpdated(_contract, _allowed);
    }

    function setBridgeReceiver(address _receiverAddress) external onlyOwner {
        numaBridgeSatelliteReceiver = INumaBridgeReceiver(_receiverAddress);
        emit BridgeReceiverUpdated(_receiverAddress);
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
        emit MinterUpdated(_minter);
      
    }

    function mint(address _to, uint256 _amount) public {
        require(msg.sender == minter,"not allowed");
        _mint(_to, _amount);
    }

    function sharedDecimals() public view override returns (uint8) {
        return 6;
    }


    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override onlyAllowed returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }



    // satellite receive override
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,//payload
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal virtual override {

        require(address(numaBridgeSatelliteReceiver) != address(0), "NumaBridgeSatelliteReceiver not set");

        // @dev sendTo is always a bytes32 as the remote chain initiating the call doesnt know remote chain address size
        address toAddress = _message.sendTo().bytes32ToAddress();
        uint256 amountToCreditLD = _toLD(_message.amountSD());

        _mint(address(numaBridgeSatelliteReceiver), amountToCreditLD);

        // no slippage check for now
        uint minSwapAmount = 0;
        numaBridgeSatelliteReceiver.onReceive(
            amountToCreditLD,
            minSwapAmount,
            toAddress);

        emit OFTReceived(_guid,_origin.srcEid, toAddress, amountToCreditLD);
    }   
}
