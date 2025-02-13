// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface ICollateralToken {
    function burn(uint256 _amountToBurn) external;
    function mint(address _to, uint256 _amountToMint) external;
}
