// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
contract Numa is ERC20,ERC20Burnable {

    address minter;
    constructor(string memory _name, string memory _symbol,address _minter) ERC20(_name, _symbol) 
    {
        minter = _minter;
    }

    function mint(address _to, uint256 _amount) public {
        require(msg.sender == minter);
        _mint(_to, _amount);
    }
}
