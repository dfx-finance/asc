// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract State is ERC20Upgradeable, AccessControlUpgradeable {
    /***** Constants *****/

    // Super user role
    bytes32 constant public SUDO_ROLE = keccak256("asc.role.sudo");
    bytes32 constant public SUDO_ROLE_ADMIN = keccak256("asc.role.sudo.admin");

    uint256 constant public MINT_BURN_FEE = 5e15;

    /***** Variables *****/

    /* !!!! Important !!!! */
    // Do _not_ change the layout of the variables
    // as you'll be changing the slots

    // Underlyings of the algo stablecoin
    address[] public underlying;

    // Ratios of the underlyings, need to add up to one
    uint256[] public backingRatio;

    // How much delta will each 'poke' consist of
    // Manually set for now
    int256[] public pokeDelta;

    // Fee recipient
    address public feeRecipient;
}