// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract State is
    AccessControlUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /***** Constants *****/

    // Super user role
    bytes32 public constant SUDO_ROLE = keccak256("asc.role.sudo");
    bytes32 public constant SUDO_ROLE_ADMIN = keccak256("asc.role.sudo.admin");

    // Poke role
    bytes32 public constant POKE_ROLE = keccak256("asc.role.poke");
    bytes32 public constant POKE_ROLE_ADMIN = keccak256("asc.role.poke.admin");

    // Market makers don't need to pay a mint/burn fee
    bytes32 public constant MARKET_MAKER_ROLE = keccak256("asc.role.mm");
    bytes32 public constant MARKET_MAKER_ROLE_ADMIN =
        keccak256("asc.role.mm.admin");

    // Can only poke the contracts every 1 day
    uint256 public constant POKE_WAIT_PERIOD = 1 days;

    /***** Variables *****/

    /* !!!! Important !!!! */
    // Do _not_ change the layout of the variables
    // as you'll be changing the slots

    // Underlyings of the algo stablecoin
    address[] public underlying;

    // How much underlying per token
    uint256[] public underlyingPerToken;

    // How much delta will each 'poke' consist of
    // Manually set for now.
    // By default, make sure its a negative value for
    // the stable asset, and a positive value for the volatile asset
    // As we'd like to decrease reliability on the stable assets
    // and increase reliability on the volatile asset gradually
    int256[] public pokeDelta;

    // Fee recipient and mint/burn fee, starts off at 0.5%
    address public feeRecipient;
    uint256 public mintBurnFee;

    // Last poke time
    uint256 public lastPokeTime;
}
