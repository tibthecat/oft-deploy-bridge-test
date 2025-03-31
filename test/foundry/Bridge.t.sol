// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


// OFT imports
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { Origin, ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";


// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/console2.sol";


import "../mocks/Lst.sol";
import "../mocks/Vault.sol";
import "../mocks/Numa.sol";
import {NumaMinter} from "../mocks/NumaMinter.sol";
//
import "../../contracts/NumaOFTAdapter.sol";
import "../../contracts/NumaOFT.sol";
import "../../contracts/NumaBridgeMaster.sol";
import "../../contracts/NumaBridgeSatellite.sol";



// DevTools imports
import { TestHelperOz5 } from "./test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

interface IOAppSetPeer {
    function setPeer(uint32 _eid, bytes32 _peer) external;
    function endpoint() external view returns (ILayerZeroEndpointV2 iEndpoint);
}

contract BridgeTest is TestHelperOz5 {

    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;


    address private deployer = address(0x42);
    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 100 ether;


    Numa public numa1;
    Lst public lst1;
    NumaMinter public numaMinter1;
    NumaVaultMock public vault1;

    //Numa public numa2;
    Lst public lst2;
    NumaMinter public numaMinter2;
    NumaVaultMock public vault2;

    // OFT

    NumaOFTAdapter public numaOFTAdapter1;
    NumaOFT public numaOFT2;

    NumaBridgeMaster public numaBridgeMaster1;
    NumaBridgeSatellite public numaBridgeSatellite2;



    function setUp() public virtual override {
        
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        vm.startPrank(deployer);
        // deploy contracts
        // numa protocol
        numaMinter1 = NumaMinter(_deployOApp(type(NumaMinter).creationCode,abi.encode("")));
        numa1 = Numa(_deployOApp(type(Numa).creationCode, abi.encode("Numa", "NUMA", address(numaMinter1))));
        lst1 = Lst(_deployOApp(type(Lst).creationCode, abi.encode("Lst", "LST")));
        

        numaMinter2 = NumaMinter(_deployOApp(type(NumaMinter).creationCode,abi.encode("")));        
        lst2 = Lst(_deployOApp(type(Lst).creationCode, abi.encode("Lst", "LST")));
      

        // Deploy OFT
        numaOFTAdapter1 = NumaOFTAdapter(_deployOApp(type(NumaOFTAdapter).creationCode, abi.encode(address(numa1), address(endpoints[aEid]),deployer)));
        // TODO: for now can only mint at lzreceive
        // BUT we need to add a minter contract so that vault and printer can also mint
        numaOFT2 = NumaOFT(_deployOApp(type(NumaOFT).creationCode,abi.encode("Numa", "NUMA2", address(endpoints[bEid]), deployer)));
        numaOFT2.setMinter(address(numaMinter2));

        // vault mocks
        vault1 = NumaVaultMock(_deployOApp(type(NumaVaultMock).creationCode,abi.encode(address(numa1),address(lst1),address(numaMinter1))));
        vault2 = NumaVaultMock(_deployOApp(type(NumaVaultMock).creationCode,abi.encode(address(numaOFT2),address(lst2),address(numaMinter2))));



        // minting rights
        //bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");
        numaMinter1.addToMinters(address(vault1));
        numaMinter2.addToMinters(address(vault2));
        numaMinter1.setTokenAddress(address(numa1));
        numaMinter2.setTokenAddress(address(numaOFT2));

        // WOULD BE NECESSARY FOR REAL DEPLOYMENT
        // numa1.grantRole(MINTER_ROLE, address(numaMinter1));
        // numa2.grantRole(MINTER_ROLE, address(numaMinter2));

        //HANDLE REMOVE SUPPLY FROM VAULTMANAGER

        // GET SOME RETH
        lst1.mint(userA, 100 ether);
        lst2.mint(userA, 100 ether);

        lst1.mint(address(vault1), 10 ether);
        lst2.mint(address(vault2), 10 ether);


        numaBridgeMaster1 = NumaBridgeMaster(_deployOApp(type(NumaBridgeMaster).creationCode,abi.encode(address(vault1),address(numaOFTAdapter1),address(numa1),address(lst1))));
        numaBridgeSatellite2 = NumaBridgeSatellite(_deployOApp(type(NumaBridgeSatellite).creationCode,abi.encode(address(vault2),address(numaOFT2),address(lst2))));
        

        // whitelist endpoints
        numaBridgeMaster1.setWhitelistedEndpoint(bEid,true);
        numaBridgeSatellite2.setWhitelistedEndpoint(aEid,true);

        // whitelist bridges
        numaOFTAdapter1.setAllowedContract(address(numaBridgeMaster1),true);
        numaOFT2.setAllowedContract(address(numaBridgeSatellite2),true);

        numaOFTAdapter1.setBridgeReceiver(address(numaBridgeMaster1));
        numaOFT2.setBridgeReceiver(address(numaBridgeSatellite2));

        numaBridgeMaster1.unpause();
        numaBridgeSatellite2.unpause();

        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(numaOFTAdapter1);
        ofts[1] = address(numaOFT2);
        console2.log("deployer",deployer);

        // manually to keep msg.sender as deployer
        //this.wireOApps(ofts);
        // 
        IOAppSetPeer localOApp = IOAppSetPeer(ofts[0]);
        IOAppSetPeer remoteOApp = IOAppSetPeer(ofts[1]);
        uint32 remoteEid = (remoteOApp.endpoint()).eid();
        localOApp.setPeer(remoteEid, addressToBytes32(address(remoteOApp)));
        //
        localOApp = IOAppSetPeer(ofts[1]);
        remoteOApp = IOAppSetPeer(ofts[0]);
        remoteEid = (remoteOApp.endpoint()).eid();
        localOApp.setPeer(remoteEid, addressToBytes32(address(remoteOApp))); 


        vm.stopPrank();

    }



    function test_constructor() public {



    }
    function test_vaults() public {
        vm.startPrank(userA);
       
        // vault on chain 1
        lst1.approve(address(vault1), 100 ether);
        numa1.approve(address(vault1), 100 ether);
        vault1.buy(1 ether, 0, userA);

        console.log("numa bought: ",numa1.balanceOf(userA));
        assertEq(numa1.balanceOf(userA), 1 ether);

        vault1.sell(0.5 ether, 0, userA);
        console.log("numa left: ",numa1.balanceOf(userA));
        assertEq(numa1.balanceOf(userA), 0.5 ether);

        
        // vault on chain 2
        lst2.approve(address(vault2), 100 ether);
        numaOFT2.approve(address(vault2), 100 ether);
        vault2.buy(1 ether, 0, userA);

        console.log("numa bought: ",numaOFT2.balanceOf(userA));
        assertEq(numaOFT2.balanceOf(userA), 1 ether);

        vault2.sell(0.5 ether, 0, userA);
        console.log("numa left: ",numaOFT2.balanceOf(userA));
        assertEq(numaOFT2.balanceOf(userA), 0.5 ether);

        vm.stopPrank();
    }

    function bridgeFrom1to2(uint amount) public
    {
        // buying for 0.1 reth of numa and bridging
       
        lst1.approve(address(numaBridgeMaster1),amount);

        // fees
        uint feesNative = numaBridgeMaster1.estimateFee(amount,userA,bEid);

        numaBridgeMaster1.buyAndBridge{value: feesNative}(amount, 0, userA,bEid);

        verifyPackets(bEid, addressToBytes32(address(numaOFT2)));


    }

    function test_send_oft_adapter() public {

       
        vm.startPrank(userA);
        uint balBefore = lst1.balanceOf(userA);
        uint amount = 0.1 ether;
        bridgeFrom1to2(amount);
             
        // userA should have less lst
        assertEq(lst1.balanceOf(userA), balBefore - amount);
        // some numa should be locked in adapter
        assertEq(numa1.balanceOf(address(numaOFTAdapter1)), amount);
        // some reth should have been minted on chain 2 to userA
        assertEq(numaOFT2.totalSupply(), 0);
        assertEq(lst2.balanceOf(userA), 100 ether +amount);
  
        vm.stopPrank();
    }

     function test_send_oft_enoughLiquidityChainA() public {

        vm.startPrank(userA);

        uint amount = 0.2 ether;
        bridgeFrom1to2(amount);

        // buying for 0.1 reth of numa and bridging
        uint balBefore = lst2.balanceOf(userA);
        uint balBefore1 = lst1.balanceOf(userA);
        uint supplyBefore = lst1.totalSupply();
        uint amount2 = 0.199 ether;
        lst2.approve(address(numaBridgeSatellite2), amount2);

        // fees
        uint feesNative = numaBridgeSatellite2.estimateFee(amount2,userA,aEid);

        numaBridgeSatellite2.buyAndBridge{value: feesNative}(amount2, 0, userA,aEid);

        verifyPackets(aEid, addressToBytes32(address(numaOFTAdapter1)));

        // userA should have less lst
        assertEq(lst2.balanceOf(userA), balBefore - amount2);

        // some numa should be unlocked in adapter
        assertEq(numa1.balanceOf(address(numaOFTAdapter1)), amount - amount2);


        assertEq(numaOFT2.totalSupply(), 0);
        //assertEq(lst1.totalSupply(), supplyBefore + amount2);

        assertEq(lst1.balanceOf(userA), balBefore1 +amount2);

        
        vm.stopPrank();
    }
    function test_send_oft_NOTenoughLiquidityChainA() public {
        vm.startPrank(userA);

        uint amount = 0.2 ether;
        bridgeFrom1to2(amount);

        // buying for 0.1 reth of numa and bridging
        uint balBefore = lst2.balanceOf(userA);
        uint balBefore1 = lst1.balanceOf(userA);
        uint supplyBefore = lst1.totalSupply();
        uint amount2 = 0.21 ether;
        lst2.approve(address(numaBridgeSatellite2), amount2);

        // fees
        uint feesNative = numaBridgeSatellite2.estimateFee(amount2,userA,aEid);

        // this should revert on chain src (b)
        vm.expectRevert("not enough liquidity");
        // vm.expectRevert();
        numaBridgeSatellite2.buyAndBridge{value: feesNative}(amount2, 0, userA,aEid);

        verifyPackets(aEid, addressToBytes32(address(numaOFTAdapter1)));

        // userA should have less lst
        assertEq(lst2.balanceOf(userA), balBefore);

        // some numa should be unlocked in adapter
        assertEq(numa1.balanceOf(address(numaOFTAdapter1)), amount);

        // some reth should have been minted on chain 1 to userA
        assertEq(numaOFT2.totalSupply(), 0);
        assertEq(lst1.totalSupply(), supplyBefore);
        assertEq(lst1.balanceOf(userA), balBefore1);

        
        vm.stopPrank();
    }

   
    function test_send_oftadapter_Handle_RevertFct() public {
        vm.startPrank(userA);
        uint balBefore = lst1.balanceOf(userA);
        uint amount = 11 ether;

        lst1.approve(address(numaBridgeMaster1),amount);
        // fees
        uint feesNative = numaBridgeMaster1.estimateFee(amount,userA,bEid);

        vm.expectRevert();// volumeTx test
        numaBridgeMaster1.buyAndBridge{value: feesNative}(amount, 0, userA,bEid);

        verifyPackets(bEid, addressToBytes32(address(numaOFT2)));

        vm.stopPrank();

        // change tx limits
        vm.prank(deployer);
        numaBridgeMaster1.updateLimits(1 hours, 20 ether,20 ether);

        vm.startPrank(userA);
        bridgeFrom1to2(amount);
        // our test will check that there is not enough liq in vault 
        // userA should have less lst
        assertEq(lst1.balanceOf(userA), balBefore - amount);
        // some numa should be locked in adapter
        assertEq(numa1.balanceOf(address(numaOFTAdapter1)), amount);
        // some reth should have been minted on chain 2 to userA
        assertEq(numaOFT2.totalSupply(), amount);
        assertEq(lst2.totalSupply(), 110 ether);
        assertEq(lst2.balanceOf(userA), 100 ether);
        assertEq(numaOFT2.balanceOf(userA), amount);
        
        vm.stopPrank();
    }

    function test_send_oft_Handle_RevertFct() public {

        // change tx limits
        vm.prank(deployer);
        numaBridgeMaster1.updateLimits(1 hours, 100 ether,100 ether);

        lst2.mint(address(vault2), 40 ether);

        uint balBeforeDbg =  lst2.balanceOf(userA);
        uint amount = 10 ether;
        //uint amount = 1.5 ether;
        vm.startPrank(userA);
        bridgeFrom1to2(amount);
        bridgeFrom1to2(amount);
        bridgeFrom1to2(amount);
        bridgeFrom1to2(amount);
        bridgeFrom1to2(amount);
         console.log("RESULT");
        console.log(numa1.balanceOf(address(numaOFTAdapter1)));
        console.log(lst2.balanceOf(userA) - balBeforeDbg);
        console.log(numaOFT2.balanceOf(userA));
        vault1.emptyVault(amount * 5);// so that there is not enough balance to sell numa

        uint balBefore = lst2.balanceOf(userA);
        uint balBefore1 = lst1.balanceOf(userA);
        uint supplyBefore = lst1.totalSupply();
        uint amount2 = 20 ether;
        lst2.approve(address(numaBridgeSatellite2), amount2);

        // fees
        uint feesNative = numaBridgeSatellite2.estimateFee(amount2,userA,aEid);
        vm.expectRevert();
        numaBridgeSatellite2.buyAndBridge{value: feesNative}(amount2, 0, userA,aEid);

        vm.stopPrank();
        vm.prank(deployer);
        numaBridgeSatellite2.updateLimits(1 hours, 20 ether,20 ether);

        vm.startPrank(userA);
        numaBridgeSatellite2.buyAndBridge{value: feesNative}(amount2, 0, userA,aEid);
        verifyPackets(aEid, addressToBytes32(address(numaOFTAdapter1)));

        // userA should have less lst
        assertEq(lst2.balanceOf(userA), balBefore - amount2);



        assertEq(numaOFT2.totalSupply(), 0);
        console2.log(balBefore1);
        console2.log(lst1.balanceOf(userA));
        assertEq(lst1.balanceOf(userA), balBefore1);
        assertEq(numa1.balanceOf(userA), amount2);
        // some numa should be unlocked in adapter
        assertEq(numa1.balanceOf(address(numaOFTAdapter1)), 5*amount - amount2);
        
        vm.stopPrank();
    }



    // TODO: other way
    function test_send_oft_Handle_RevertRaw() public {
        vm.startPrank(userA);
         
        vm.stopPrank();
    }

    function test_bridge_min() public {

        vm.startPrank(userA);
        uint amount = 1e12;
        bridgeFrom1to2(amount);


        amount = 1e11;
        
        lst1.approve(address(numaBridgeMaster1),amount);

        // fees
        vm.expectRevert();
        uint feesNative = numaBridgeMaster1.estimateFee(amount,userA,bEid);
 

        vm.expectRevert();
        numaBridgeMaster1.buyAndBridge{value: 1 ether}(amount, 0, userA,bEid);


               
        lst2.approve(address(numaBridgeSatellite2),amount);

        vm.expectRevert();
        feesNative = numaBridgeSatellite2.estimateFee(amount,userA,aEid);
        
        vm.expectRevert();
        numaBridgeSatellite2.buyAndBridge{value: 1 ether}(amount, 0, userA,aEid);

 
   

    }

    function test_bridge_not_allowed() public {
        // adapter --> OFT
        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = numaOFTAdapter1.quoteSend(sendParam, false);



        vm.startPrank(userA);
        numa1.approve(address(numaOFTAdapter1), tokensToSend);
        vm.expectRevert("Not allowed to bridge");
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = numaOFTAdapter1.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(numaOFT2)));

        // OFT --> adapter
        sendParam = SendParam(
            aEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
       fee = numaOFT2.quoteSend(sendParam, false);
       vm.expectRevert("Not allowed to bridge");
       (msgReceipt, oftReceipt) = numaOFT2.send{ value: fee.nativeFee }(
        sendParam,
        fee,
        payable(address(this))
        );
        verifyPackets(aEid, addressToBytes32(address(numaOFTAdapter1)));
    }
  
}
