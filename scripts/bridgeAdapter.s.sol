// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
//import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OFTAdapter,MyOFTAdapter} from "../contracts/MyOFTAdapter.sol";

// OApp imports
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// OFT imports
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";


//forge script --chain sepolia .\scripts\bridgeAdapter.s.sol:BridgeOFTAdapter --rpc-url --broadcast -vv --sender 0xe8153Afbe4739D4477C1fF86a26Ab9085C4eDC69 --private-key 

contract BridgeOFTAdapter is Script {

    using OptionsBuilder for bytes;
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }


    function run() external {
        
        // sepolia numa adapter
        address oftAdapter = 0x2bC282Aa1c08eF1cedE655e70E94399A8Aaee696;
        // numa sepolia
        address token = 0xf478F8dEDebe67cC095693A9d6778dEb3fb67FFe;
        
        uint32 dstEid = 40231;
        address receiver = msg.sender;
        uint256 amount = 10 ether;
        bytes memory adapterParams = ""; // Optional, depends on your setup

        vm.startBroadcast();


        uint lockedNuma = IERC20(token).balanceOf(oftAdapter);
        console.log("lockedNuma",lockedNuma);

        // Approve the OFTAdapter to spend tokens
        IERC20(token).approve(oftAdapter, amount);
        console.log("Approved OFTAdapter to spend tokens");

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            dstEid,
            addressToBytes32(receiver),
            amount,
            amount,
            options,
            "",
            ""
        );
        MessagingFee memory fee = OFTAdapter(oftAdapter).quoteSend(sendParam, false);

 
        //aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = OFTAdapter(oftAdapter).send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );




        console.log("Bridge transaction sent!");

        vm.stopBroadcast();
    }
}
