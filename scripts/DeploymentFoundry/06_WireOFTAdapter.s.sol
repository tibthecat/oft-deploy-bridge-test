// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../contracts/NumaOFT.sol";
import "../../contracts/NumaBridgeMaster.sol";

interface IOAppSetPeer {
    function setPeer(uint32 _eid, bytes32 _peer) external;
    //function endpoint() external view returns (ILayerZeroEndpointV2 iEndpoint);
}



contract WireOFTAdapter is Script  {

    function run() external {

        string memory configData = vm.readFile("./scripts/DeploymentFoundry/config.json");
        string memory path = string(abi.encodePacked(".", vm.toString(block.chainid)));

        //
        uint satellite_chainId = vm.parseJsonUint(configData, string(abi.encodePacked(path, ".satellite_chainId")));
        uint satellite_endpoint = vm.parseJsonUint(configData, string(abi.encodePacked(path, ".satellite_endpoint")));


        string memory filenameRemote = string(
            abi.encodePacked("./scripts/DeploymentFoundry/deployed_addresses_", vm.toString(satellite_chainId), ".json")
        );
        console2.log("filename",filenameRemote);

        string memory deployedData = vm.readFile(filenameRemote);
        address oft_address = vm.parseJsonAddress(deployedData, ".numaOFT");
        console2.log("oft_address",oft_address);


        string memory filenameLocal = string(
            abi.encodePacked("./scripts/DeploymentFoundry/deployed_addresses_", vm.toString(block.chainid), ".json")
        );
        console2.log("filename",filenameLocal);

        string memory deployedData2 = vm.readFile(filenameLocal);
        address adapter_address = vm.parseJsonAddress(deployedData2, ".numaOFTAdapter");
        console2.log("adapter_address",adapter_address);


        vm.startBroadcast();
        address deployer = msg.sender;
        console2.log("deployer ",deployer);


        IOAppSetPeer localOApp = IOAppSetPeer(adapter_address);
        IOAppSetPeer remoteOApp = IOAppSetPeer(oft_address);
        uint32 remoteEid = uint32(satellite_endpoint);
        localOApp.setPeer(remoteEid, addressToBytes32(address(remoteOApp)));
  
       
        vm.stopBroadcast();
        
        
    }

    function toAsciiString(address addr) internal pure returns (string memory) {
        bytes memory s = new bytes(42);
        s[0] = "0";
        s[1] = "x";
        for (uint i = 0; i < 20; i++) {
            uint8 b = uint8(uint160(addr) / (2**(8 * (19 - i))));
            s[2 + i * 2] = _char(b / 16);
            s[3 + i * 2] = _char(b % 16);
        }
        return string(s);
    }

    function _char(uint8 b) private pure returns (bytes1) {
        return b < 10 ? bytes1(b + 48) : bytes1(b + 87);
    }
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}