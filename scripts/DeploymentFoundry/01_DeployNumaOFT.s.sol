// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../contracts/NumaOFT.sol";

contract DeployNumaOFT is Script  {


    // out
    NumaOFT public numaOFT;
  

    function run() external {

        string memory configData = vm.readFile("./scripts/DeploymentFoundry/config.json");
        string memory path = string(abi.encodePacked(".", vm.toString(block.chainid)));
        address endpoint_address = vm.parseJsonAddress(configData, string(abi.encodePacked(path, ".endpoint")));

        vm.startBroadcast();
        address deployer = msg.sender;
        console2.log("deployer ",deployer);
        // Tokens       
        numaOFT = new NumaOFT("Numa", "NUMA", endpoint_address,deployer);


  

        // Write the JSON to the specified path using writeJson
        string memory json = string(abi.encodePacked(
            '{"numaOFT": "', toAsciiString(address(numaOFT)),'"}'
        ));

        // Create the filename with the chain ID
        string memory filename = string(
            abi.encodePacked("./scripts/DeploymentFoundry/deployed_addresses_", vm.toString(block.chainid), ".json")
        );

        vm.writeJson(json, filename);
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
}