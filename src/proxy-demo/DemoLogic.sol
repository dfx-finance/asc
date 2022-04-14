// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DemoLogic {
    uint256 magicNumber;

    function initialize() public {
        magicNumber = 0x42;
    }

    function setMagicNumber(uint256 newMagicNumber) public {
        magicNumber = newMagicNumber;
    }

    function getMagicNumber() public view returns (uint256) {
        return magicNumber;
    }
}