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

    // Should only be able to initialize once
    function testFail_dfxcadc_reinitialize() public {
        admin.call(
            address(dfxCadc),
            abi.encodeWithSelector(
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
            )
        );
    }

    function test_dfxcadc_erc20() public {
        assertEq(dfxCadc.name(), "Coin");
        assertEq(dfxCadc.symbol(), "COIN");
        assertEq(dfxCadc.totalSupply(), 0);

        assertEq(upgradeableProxy.getAdmin(), address(admin));
        assertTrue(dfxCadc.hasRole(dfxCadc.SUDO_ROLE(), address(sudo)));
        assertTrue(dfxCadc.hasRole(dfxCadc.MARKET_MAKER_ROLE(), address(sudo)));
    }

    function test_dfxcadc_access_control() public {
        MockUser newUser = new MockUser();

        assertTrue(
            !dfxCadc.hasRole(dfxCadc.MARKET_MAKER_ROLE(), address(newUser))
        );
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.grantRole.selector,
                dfxCadc.MARKET_MAKER_ROLE(),
                address(newUser)
            )
        );
        assertTrue(
            dfxCadc.hasRole(dfxCadc.MARKET_MAKER_ROLE(), address(newUser))
        );

        assertTrue(!dfxCadc.hasRole(dfxCadc.SUDO_ROLE(), address(newUser)));
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.grantRole.selector,
                dfxCadc.SUDO_ROLE(),
                address(newUser)
            )
        );
        assertTrue(dfxCadc.hasRole(dfxCadc.SUDO_ROLE(), address(newUser)));
    }

    function test_dfxcadc_get_underlyings() public {
        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(
            100e18
        );
        uint256 cadPerDfx = twap.read();
        uint256 sum = cadcAmount + ((dfxAmount * cadPerDfx) / 1e18);

        // Should add to 100 CAD
        // Assume 1 CADC = 1 CAD
        assertLe(sum, 100e18);
        assertGt(sum, 9999e16);
    }

    function test_dfxcadc_mint(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e6);
        cheats.assume(lpAmount < 1_000_000_000e18);

        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(
            lpAmount
        );

        tipCadc(address(this), cadcAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);

        dfxCadc.mint(lpAmount);
        uint256 fee = (lpAmount * dfxCadc.mintBurnFee()) / 1e18;
        assertEq(dfxCadc.balanceOf(address(this)), lpAmount - fee);
    }

    function test_dfxcadc_mint_no_fees(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e6);
        cheats.assume(lpAmount < 1_000_000_000e18);

        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.grantRole.selector,
                dfxCadc.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(
            lpAmount
        );

        tipCadc(address(this), cadcAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);

        dfxCadc.mint(lpAmount);
        assertEq(dfxCadc.balanceOf(address(this)), lpAmount);
    }

    function test_dfxcadc_burn(uint256 lpAmount) public {
        test_dfxcadc_mint_no_fees(lpAmount);
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.revokeRole.selector,
                dfxCadc.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        // Burn
        dfxCadc.burn(lpAmount);

        // Mint + burn fee
        uint256 _fee = (lpAmount * dfxCadc.mintBurnFee()) / 1e18;
        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(
            lpAmount - _fee
        );

        assertEq(dfxCadc.balanceOf(address(feeCollector)), _fee);
        assertEq(cadc.balanceOf(address(this)), cadcAmount);
        assertEq(dfx.balanceOf(address(this)), dfxAmount);
    }

    function test_dfxcadc_burn_no_fee(uint256 lpAmount) public {
        test_dfxcadc_mint_no_fees(lpAmount);

        dfxCadc.burn(lpAmount);
        (uint256 cadcAmount, uint256 dfxAmount) = dfxCadc.getUnderlyings(
            lpAmount
        );

        assertEq(cadc.balanceOf(address(this)), cadcAmount);
        assertEq(dfx.balanceOf(address(this)), dfxAmount);
    }

    function test_dfxcadc_poke_up() public {
        uint256 cadcR0 = dfxCadc.cadcRatio();
        uint256 dfxR0 = dfxCadc.dfxRatio();

        (uint256 cadcAmount0, uint256 dfxAmount0) = dfxCadc.getUnderlyings(
            1e18
        );
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
        (uint256 cadcAmount1, uint256 dfxAmount1) = dfxCadc.getUnderlyings(
            1e18
        );

        uint256 cadcR1 = dfxCadc.cadcRatio();
        uint256 dfxR1 = dfxCadc.dfxRatio();

        assertLt(cadcAmount1, cadcAmount0);
        assertGt(dfxAmount1, dfxAmount0);

        assertLt(cadcR1, cadcR0);
        assertGt(dfxR1, dfxR0);
    }

    function test_dfxcadc_poke_down() public {
        uint256 cadcR0 = dfxCadc.cadcRatio();
        uint256 dfxR0 = dfxCadc.dfxRatio();

        (uint256 cadcAmount0, uint256 dfxAmount0) = dfxCadc.getUnderlyings(
            1e18
        );
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
        (uint256 cadcAmount1, uint256 dfxAmount1) = dfxCadc.getUnderlyings(
            1e18
        );

        uint256 cadcR1 = dfxCadc.cadcRatio();
        uint256 dfxR1 = dfxCadc.dfxRatio();

        assertGt(cadcAmount1, cadcAmount0);
        assertLt(dfxAmount1, dfxAmount0);

        assertGt(cadcR1, cadcR0);
        assertLt(dfxR1, dfxR0);
    }

    function test_dfxcadc_poke_up_2() public {
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxCadc.POKE_WAIT_PERIOD() + 1 minutes);
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
    }

    function testFail_dfxcadc_poke_up_2() public {
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
    }

    function test_dfxcadc_poke_down_2() public {
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxCadc.POKE_WAIT_PERIOD() + 1 minutes);
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxcadc_poke_down_2() public {
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxcadc_paused_mint() public {
        test_dfxcadc_mint(100e18);
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxcadc_mint(1e18);
    }

    function testFail_dfxcadc_paused_burn() public {
        test_dfxcadc_mint(100e18);
        test_dfxcadc_burn(1e18);
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxcadc_burn(1e18);
    }

    function test_dfxcadc_unpause() public {
        // Contract can be unpaused
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, true)
        );

        cheats.expectRevert("Pausable: paused");
        dfxCadc.mint(100e18);

        // unpause and try again
        sudo.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, false)
        );
        test_dfxcadc_mint(100e18);
    }
}
