//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./Numa.sol";

/// @title Numa minter
/// @notice maintains a list of addresses allowed to mint numa
contract NumaMinter is Ownable2Step 
{
    
    Numa public numa;
    mapping(address => bool) allowedMinters;

    // Events
    event AddedToMinters(address indexed a);
    event RemovedFromMinters(address indexed a);
    event SetToken(address token);

    modifier onlyMinters() {
        require(isMinter(msg.sender), "not allowed");
        _;
    }

    constructor() Ownable(msg.sender) {}
    

    /**
     * @notice Sets the address of the token to be minted by this contract.
     * @param _token the token to mint
     */
    function setTokenAddress(address _token) external onlyOwner {
    
        numa = Numa(_token);
        emit SetToken(_token);
    }

    /**
     * @notice mints amount of tokens to the caller.
     * @param to the receiver of the minted tokens
     * @param amount amount to be minted
     */
    function mint(address to, uint256 amount) external onlyMinters {
        require(address(numa) != address(0), "token address invalid");
        numa.mint(to, amount);
    }

    /**
     * @notice adds an address as allowed to mint token
     * @param _address address to be whitelisted to mint 
     */
    function addToMinters(address _address) public onlyOwner {
    
        allowedMinters[_address] = true;
        emit AddedToMinters(_address);
    }

    /**
     * @notice removes an address from whitelist
     * @param _address address to be removed
     */
    function removeFromMinters(address _address) public onlyOwner {
    
        allowedMinters[_address] = false;
        emit RemovedFromMinters(_address);
    }

    /**
     * @notice returns true if address is allowed to mint
     * @param _address address we want to check
     */
    function isMinter(address _address) public view returns (bool) {
        return allowedMinters[_address];
    }
}
