// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../lib/MockToken.sol";
import "../lib/MockUser.sol";
import "../lib/CheatCodes.sol";

import "../../oracles/DfxCadTWAP.sol";
import "../../dfx-cadc/DfxCadcLogic.sol";
import "../../ASCUpgradableProxy.sol";

contract DfxCadcLogicTest is DSTest {
    // Did it this way to obtain interface
    DfxCadcLogic proxy;

    ASCUpgradableProxy upgradeableProxy;
    DfxCadcLogic logic;
    DfxCadTWAP twap;

    // Mock users so we can have many addresses
    MockUser admin;
    MockUser sudo;
    MockUser feeCollector;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    // MINT BURN FEE
    // 0.5%
    uint256 internal constant MINT_BURN_FEE = 5e15;

    // Ratios
    uint256 internal constant DFX_RATIO = 5e16; // 5%
    uint256 internal constant CADC_RATIO = 95e16; // 95%s
    uint256 internal constant POKE_DELTA_RATIO = 1e16; // 1%

    function setUp() public {
        admin = new MockUser();
        sudo = new MockUser();
        feeCollector = new MockUser();

        twap = new DfxCadTWAP();
        cheats.warp(block.timestamp + 1 days);
        cheats.prank(address(this), address(this));
        twap.update();

        logic = new DfxCadcLogic();
        bytes memory callargs = abi.encodeWithSelector(
            DfxCadcLogic.initialize.selector,
            "Coin",
            "COIN",
            address(sudo),
            address(feeCollector),
            MINT_BURN_FEE,
            address(twap),
            CADC_RATIO,
            DFX_RATIO,
            POKE_DELTA_RATIO
        );

        upgradeableProxy = new ASCUpgradableProxy(
            address(logic),
            address(admin),
            callargs
        );

        proxy = DfxCadcLogic(address(upgradeableProxy));
    }

    function test_dfxcadc_get_underlyings() public {
        (uint256 cadcAmount, uint256 dfxAmount) = proxy.getUnderlyings(100e18);
        uint256 cadPerDfx = twap.read();
        uint256 sum = cadcAmount + (dfxAmount * cadPerDfx / 1e18);

        // Should add to 100 CAD
        // Assume 1 CADC = 1 CAD
        assertLe(sum, 100e18);
        assertGt(sum, 9999e16);
    }
}
