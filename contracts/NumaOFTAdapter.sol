// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

//
import "./interfaces/INumaBridgeReceiver.sol";
//
import { OFTAdapter } from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import { OFTCore,MessagingFee, MessagingReceipt,Origin} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {SendParam,OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
//
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";




/**
 * @title OFTAdapter Contract
 * @dev OFTAdapter is a contract that adapts an ERC-20 token to the OFT functionality.
 *
 * @dev For existing ERC20 tokens, this can be used to convert the token to crosschain compatibility.
 * @dev WARNING: ONLY 1 of these should exist for a given global mesh,
 * unless you make a NON-default implementation of OFT and needs to be done very carefully.
 * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
 * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
 * a pre/post balance check will need to be done to calculate the amountSentLD/amountReceivedLD.
 */
contract NumaOFTAdapter is OFTAdapter {

    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;
    using SafeERC20 for IERC20;

    INumaBridgeReceiver public numaBridgeMasterReceiver;
    mapping(address => bool) public allowedContracts;


    event AllowedContractUpdated(address indexed contractAddress, bool allowed);
    event BridgeReceiverUpdated(address indexed contractAddress);

    // Address type handling
    function bytes32ToAddress(bytes32 _bytes32Address) internal pure returns (address _address) {
        return address(uint160(uint(_bytes32Address)));
    }

    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate
    ) OFTAdapter(_token, _lzEndpoint, _delegate) Ownable(_delegate) {}


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

    // Admin function to update allowed contracts
    function setBridgeReceiver(address _receiverAddress) external onlyOwner {
        numaBridgeMasterReceiver = INumaBridgeReceiver(_receiverAddress);
        emit BridgeReceiverUpdated(_receiverAddress);
    }


    function sharedDecimals() public view override returns (uint8) {
        return 6;
    }


    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override onlyAllowed returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        // @dev Lock tokens by moving them into this contract from the caller.
        innerToken.safeTransferFrom(_from, address(this), amountSentLD);
    }



      // satellite receive override
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,//payload
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal virtual override {

        require(address(numaBridgeMasterReceiver) != address(0), "numaBridgeMasterReceiver not set");

        // @dev sendTo is always a bytes32 as the remote chain initiating the call doesnt know remote chain address size
        address toAddress = _message.sendTo().bytes32ToAddress();

        uint256 amountToCreditLD = _toLD(_message.amountSD());

        // @dev Unlock the tokens and transfer to the recipient.
        SafeERC20.safeTransfer(
            innerToken,            
            address(numaBridgeMasterReceiver),
            amountToCreditLD);


        //_mint(address(bridgeReceiver), amountToCreditLD);
        // no slippage check for now
        uint minSwapAmount = 0;
        numaBridgeMasterReceiver.onReceive(
            amountToCreditLD,
            minSwapAmount,
            toAddress);

        emit OFTReceived(_guid,_origin.srcEid, toAddress, amountToCreditLD);
    }   

}
