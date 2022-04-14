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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./MUNIState.sol";

import "../../libraries/FullMath.sol";

contract MUNILogicV1 is MUNIState {
    using SafeERC20 for IERC20;

    // **** Initializing functions ****

    // We don't need to check twice if the contract's initialized as
    // __ERC20_init does that check
    // function initialize() {

    // }
}
