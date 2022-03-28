// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "./ERC20Upgradeable.sol";

contract DfxCadcState is
    AccessControlUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /***** Constants *****/

    // Super user role
    bytes32 public constant SUDO_ROLE = keccak256("dfxcadc.role.sudo");
    bytes32 public constant SUDO_ROLE_ADMIN = keccak256("dfxcadc.role.sudo.admin");

    // Poke role
    bytes32 public constant POKE_ROLE = keccak256("dfxcadc.role.poke");
    bytes32 public constant POKE_ROLE_ADMIN = keccak256("dfxcadc.role.poke.admin");

    // Market makers don't need to pay a mint/burn fee
    bytes32 public constant MARKET_MAKER_ROLE = keccak256("dfxcadc.role.mm");
    bytes32 public constant MARKET_MAKER_ROLE_ADMIN =
        keccak256("dfxcadc.role.mm.admin");
    
    // Collateral defenders to perform buyback and recollateralization
    bytes32 public constant CR_DEFENDER = keccak256("dfxcadc.role.cr-defender");
    bytes32 public constant CR_DEFENDER_ADMIN = keccak256("dfxcadc.role.cr-defender.admin");

    // Can only poke the contracts every day
    uint256 public constant POKE_WAIT_PERIOD = 1 days;
    uint256 public constant MAX_POKE_RATIO_DELTA = 1e16; // 1% max change per day

    // Underlyings
    address public constant DFX = 0x888888435FDe8e7d4c54cAb67f206e4199454c60;
    address public constant CADC = 0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef;

    /***** Variables *****/

    /* !!!! Important !!!! */
    // Do _not_ change the layout of the variables
    // as you'll be changing the slots

    // TWAP Oracle address
    // 1 DFX = X CAD?
    address public dfxCadTwap;

    // Will only be backed by DFX and CADC so this should be sufficient
    // Ratio should be number between 0 - 1e18
    // dfxRatio + cadcRatio should equal to 1e18
    // 5e17 = ratio of 50%
    uint256 public cadcRatio;
    uint256 public dfxRatio;

    // How much delta will each 'poke' consist of
    // i.e. say pokeRatioDelta = 1e16 = 1%
    //      dfxRatio = 5e17 = 50%
    //      cadcRatio = 5e17 = 50%
    // Poking up = dfxRatio = 51e16 = 51%
    //             cadcRatio = 49e16 = 49%
    // Poking down = dfxRatio = 49e16 = 49%
    //             cadcRatio = 51e16 = 51%
    uint256 public pokeRatioDelta;

    // Fee recipient and mint/burn fee, starts off at 0.5%
    address public feeRecipient;
    uint256 public mintBurnFee;

    // Last poke time
    uint256 public lastPokeTime;
}
