// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../contracts/NumaOFT.sol";
import "../../contracts/NumaBridgeSatellite.sol";
contract DeployBridgeSatellite is Script  {

    // out
    NumaBridgeSatellite public numaBridgeSatellite;


    function run() external {

        string memory configData = vm.readFile("./scripts/DeploymentFoundry/config.json");
        string memory path = string(abi.encodePacked(".", vm.toString(block.chainid)));

        address vault_address = vm.parseJsonAddress(configData, string(abi.encodePacked(path, ".vault")));

        address lst_address = vm.parseJsonAddress(configData, string(abi.encodePacked(path, ".lst")));
        uint master_endpoint = vm.parseJsonUint(configData, string(abi.encodePacked(path, ".master_endpoint")));

        string memory filename = string(
            abi.encodePacked("./scripts/DeploymentFoundry/deployed_addresses_", vm.toString(block.chainid), ".json")
        );
        console2.log("filename",filename);

        string memory deployedData = vm.readFile(filename);
        address numaOFT_address = vm.parseJsonAddress(deployedData, ".numaOFT");
        console2.log("numaOFT_address",numaOFT_address);



        vm.startBroadcast();
        address deployer = msg.sender;
        console2.log("deployer ",deployer);

        numaBridgeSatellite = new NumaBridgeSatellite(vault_address,numaOFT_address,lst_address);
        

        // whitelist endpoints
        numaBridgeSatellite.setWhitelistedEndpoint(uint32(master_endpoint),true);
        numaBridgeSatellite.setGasLimitEndpoint(uint32(master_endpoint),500_000);

        // whitelist bridges
        NumaOFT numaOFT = NumaOFT(numaOFT_address);
        numaOFT.setAllowedContract(address(numaBridgeSatellite),true);
        numaOFT.setBridgeReceiver(address(numaBridgeSatellite));

        // paused by default
        //numaBridgeSatellite2.unpause();


        // Write the JSON to the specified path using writeJson
        string memory json = string(abi.encodePacked(
            '{"numaOFT": "', toAsciiString(address(numaOFT)), '", ',
            '"BridgeSatellite": "', toAsciiString( address(numaBridgeSatellite)), '"}'
        ));

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