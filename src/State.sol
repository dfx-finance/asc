// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract State is
    AccessControlUpgradeable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable
{
    /***** Constants *****/

    // Super user role
    bytes32 public constant SUDO_ROLE = keccak256("asc.role.sudo");
    bytes32 public constant SUDO_ROLE_ADMIN = keccak256("asc.role.sudo.admin");

    // Market makers don't need to pay a mint/burn fee
    bytes32 public constant MARKET_MAKER_ROLE = keccak256("asc.role.mm");
    bytes32 public constant MARKET_MAKER_ROLE_ADMIN =
        keccak256("asc.role.mm.admin");

    // 0.5% fee, for now
    uint256 public constant MINT_BURN_FEE = 5e15;

    // Can only poke the contracts every 6 hours
    uint256 public constant POKE_WAIT_PERIOD = 6 hours;

    /***** Variables *****/

    /* !!!! Important !!!! */
    // Do _not_ change the layout of the variables
    // as you'll be changing the slots

    // Underlyings of the algo stablecoin
    address[] public underlying;

    // Ratios of the underlyings, need to add up to one
    uint256[] public backingRatio;

    // How much delta will each 'poke' consist of
    // Manually set for now.
    // By default, make sure its a negative value for
    // the stable asset, and a positive value for the volatile asset
    // As we'd like to decrease reliability on the stable assets
    // and increase reliability on the volatile asset gradually
    int256[] public pokeDelta;

    // Fee recipient
    address public feeRecipient;

    // Last poke time
    uint256 public lastPokeTime;
}
