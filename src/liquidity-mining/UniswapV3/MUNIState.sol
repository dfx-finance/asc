// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/*
    Inspired by https://github.com/gelatodigital/g-uni-v1-core/blob/master/contracts/GUniPool.sol#L135

    MUNI (Managed Uni)

    As of Uniswap V3, liquidity positions will be represented by an NFT.
    Managing LPs efficiently is within the protocols interest, such as
    concentrating liquidity between a certain range for like-minded pairs.

    MUNI will be responsible for managing said positions while issuing out a ERC20 token as a receipt
*/

import "../../interfaces/IUniswapV3.sol";

import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "./ERC20Upgradeable.sol";

contract MUNIState is
    AccessControlUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /***** Constants *****/

    // Super user role
    bytes32 public constant SUDO_ROLE = keccak256("muni.role.sudo");
    bytes32 public constant SUDO_ROLE_ADMIN = keccak256("muni.role.sudo.admin");

    /***** Variables *****/

    /* !!!! Important !!!! */
    // Do _not_ change the layout of the variables
    // as you'll be changing the slots

    // Management fee and accounting
    uint16 public managerFeeBPS;
    uint256 public managerBalance0;
    uint256 public managerBalance1;

    // Management variables - slippages
    uint32 slippageInterval = 5 minutes;
    uint16 slippageBPS = 500; // 5%
    uint16 withdrawBPS = 100; // 1%
    uint16 rebalanceBPS = 200; // 2%

    int24 public lowerTick;
    int24 public upperTick;

    // IUniswapV3Pool public immutable pool;
    // IERC20 public immutable token0;
    // IERC20 public immutable token1;
}
