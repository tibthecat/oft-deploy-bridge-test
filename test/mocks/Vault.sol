// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NumaMinter.sol";
import "./Numa.sol";
import "./Lst.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console2.sol";

contract NumaVaultMock {


    Numa public immutable numa;
    Lst public immutable lst;
    NumaMinter public immutable minter;
    constructor(address _numaAddress,address _lstAddress,address _minterAddress) 
    {
        numa = Numa(_numaAddress);
        lst = Lst(_lstAddress);
        minter = NumaMinter(_minterAddress);

    }


    function lstToNuma(uint256 _amount) external view returns (uint256) 
    {
        return _amount;
    }

    function numaToLst(uint256 _amount) external view returns (uint256) 
    {
        return _amount;
    }
    function buy(uint amount, uint min, address recipient) external returns (uint)
    {
        SafeERC20.safeTransferFrom(
            lst,
            msg.sender,
            address(this),
            amount);

        minter.mint(recipient, amount);
        
        return amount;

    }

    function sell(uint amount, uint min, address recipient) external returns (uint)
    {
        console2.log("burning token ",address(numa));
        numa.burnFrom(msg.sender, amount);// TODO revert test 1
        //lst.mint(recipient, amount);
        SafeERC20.safeTransfer(
            lst,
            recipient,
            amount);
        return amount;

    }

    function emptyVault(uint amount) external returns (uint)
    {
       
        SafeERC20.safeTransfer(
            lst,

            address(0x6666666666666666666666666666666666666666),
            amount);
        return amount;

    }

}
