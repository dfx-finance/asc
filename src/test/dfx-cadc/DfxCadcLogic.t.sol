// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import {stdCheats} from "@forge-std/stdlib.sol";

import "../lib/MockToken.sol";
import "../lib/MockUser.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import "../../oracles/DfxCadTWAP.sol";
import "../../dfx-cadc/DfxCadcLogic.sol";
import "../../ASCUpgradableProxy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DfxCadcLogicTest is DSTest, stdCheats {
    // Did it this way to obtain interface
    DfxCadcLogic dfxCadc;

    ASCUpgradableProxy upgradeableProxy;
    DfxCadcLogic logic;
    DfxCadTWAP twap;

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 cadc = IERC20(Mainnet.CADC);

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

        dfxCadc = DfxCadcLogic(address(upgradeableProxy));
        
        cadc.approve(address(dfxCadc), type(uint256).max);
        dfx.approve(address(dfxCadc), type(uint256).max);
    }

    function tipCadc(address _recipient, uint256 _amount) internal {
        // Tip doesn't work on proxies :\
        cheats.store(
            Mainnet.CADC,
            keccak256(abi.encode(_recipient, 9)), // slot 9
            bytes32(_amount)
        );
    }

    function test_dfxcadc_get_underlyings() public {
        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(100e18);
        uint256 cadPerDfx = twap.read();
        uint256 sum = cadcAmount + (dfxAmount * cadPerDfx / 1e18);

        // Should add to 100 CAD
        // Assume 1 CADC = 1 CAD
        assertLe(sum, 100e18);
        assertGt(sum, 9999e16);
    }

    function test_dfxcadc_mint(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e6);
        cheats.assume(lpAmount < 1_000_000_000e18);

        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(lpAmount);

        tipCadc(address(this), cadcAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);

        dfxCadc.mint(lpAmount);
        uint256 fee = lpAmount * dfxCadc.mintBurnFee() / 1e18;
        assertEq(dfxCadc.balanceOf(address(this)), lpAmount - fee);
    }
}
