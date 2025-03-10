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


//forge script --chain sepolia .\scripts\bridgeOFT.s.sol:BridgeOFT --rpc-url --broadcast -vv --sender 0xe8153Afbe4739D4477C1fF86a26Ab9085C4eDC69 --private-key 

contract BridgeOFT is Script {

    using OptionsBuilder for bytes;
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }


    function run() external {
        
        // arbitrum sepolia oft numa
        address oft = 0xE6A422d4Bdd3c5e16709D08D24E210738Ac75329;

        uint32 dstEid = 40161;
        address receiver = msg.sender;
        uint256 amount = 10 ether;
        bytes memory adapterParams = ""; // Optional, depends on your setup

        vm.startBroadcast();



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


       MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);

       (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = IOFT(oft).send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );


        console.log("Bridge transaction sent!");

        vm.stopBroadcast();
    }
}
