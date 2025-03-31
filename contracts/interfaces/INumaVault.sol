// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface INumaVault {
    function buy(uint, uint, address) external returns (uint);
    function sell(uint, uint, address) external returns (uint);
    function lstToNuma(uint256 _amount) external view returns (uint256);
    function numaToLst(uint256 _amount) external view returns (uint256);
}
