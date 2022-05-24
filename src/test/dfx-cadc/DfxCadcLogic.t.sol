// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import {stdCheats} from "@forge-std/stdlib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../lib/MockToken.sol";
import "../lib/MockUser.sol";
import "../lib/MockLogic.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import "../../oracles/DfxCadTWAP.sol";
import "../../dfx-cadc/DfxCadcLogic.sol";
import "../../ASCUpgradableProxy.sol";

import "../../interfaces/IDfxCurve.sol";

contract DfxCadcLogicTest is DSTest, stdCheats {
    // Did it this way to obtain interface
    DfxCadcLogic dfxCadc;

    ASCUpgradableProxy upgradeableProxy;
    DfxCadcLogic logic;
    DfxCadTWAP twap;

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 cadc = IERC20(Mainnet.CADC);
    IERC20 usdc = IERC20(Mainnet.USDC);

    // Mock users so we can have many addresses
    MockUser admin;
    MockUser accessAdmin;
    MockUser feeCollector;
    MockUser regularUser;

    MockLogic ml;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    // MINT BURN FEE
    // 0.5%
    uint256 internal constant MINT_BURN_FEE = 5e15;

    // Ratios
    uint256 internal constant DFX_RATIO = 5e16; // 5%
    uint256 internal constant CADC_RATIO = 95e16; // 95%s
    uint256 internal constant POKE_DELTA_RATIO = 1e16; // 1%

    // Used to calculate spot prices
    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(Mainnet.SUSHI_ROUTER);
    IDfxCurve dfxUsdcCadcA =
        IDfxCurve(0xa6C0CbCaebd93AD3C6c94412EC06aaA37870216d);

    function setUp() public {
        ml = new MockLogic();
        admin = new MockUser();
        accessAdmin = new MockUser();
        regularUser = new MockUser();
        feeCollector = new MockUser();

        twap = new DfxCadTWAP(address(this));
        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();

        logic = new DfxCadcLogic();
        bytes memory callargs = abi.encodeWithSelector(
            DfxCadcLogic.initialize.selector,
            "Coin",
            "COIN",
            address(accessAdmin),
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
                address(accessAdmin),
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
        assertTrue(dfxCadc.hasRole(dfxCadc.SUDO_ROLE(), address(accessAdmin)));
        assertTrue(dfxCadc.hasRole(dfxCadc.MARKET_MAKER_ROLE(), address(accessAdmin)));
    }

    function test_dfxcadc_access_control() public {
        MockUser newUser = new MockUser();

        assertTrue(
            !dfxCadc.hasRole(dfxCadc.MARKET_MAKER_ROLE(), address(newUser))
        );
        accessAdmin.call(
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
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.grantRole.selector,
                dfxCadc.SUDO_ROLE(),
                address(newUser)
            )
        );
        assertTrue(dfxCadc.hasRole(dfxCadc.SUDO_ROLE(), address(newUser)));
    }

    function testFail_dfxcadc_access_pokedelta() public {
        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPokeDelta.selector, 1e15)
        );
    }

    function testFail_dfxcadc_access_pokeUp() public {
        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector)
        );
    }

    function testFail_dfxcadc_access_pokeDown() public {
        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector)
        );
    }

    function testFail_dfxcadc_access_setdfxcadtwap() public {
        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setDfxCadTwap.selector, address(0))
        );
    }

    function testFail_dfxcadc_access_recoverERC20() public {
        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.recoverERC20.selector, Mainnet.DAI)
        );
    }

    function testFail_dfxcadc_access_execute() public {
        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.execute.selector,
                address(ml),
                abi.encodeWithSelector(ml.doSomething.selector)
            )
        );
    }

    function test_dfxcadc_access_execute() public {
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.grantRole.selector,
                dfxCadc.CR_DEFENDER(),
                address(regularUser)
            )
        );

        regularUser.call(
            address(dfxCadc),
            abi.encodeWithSelector(
                dfxCadc.execute.selector,
                address(ml),
                abi.encodeWithSelector(ml.doSomething.selector)
            )
        );
    }

    function test_dfxcad_recollateralize() public {
        uint256 cadPerDfx = twap.read();
        emit log_uint(cadPerDfx);
        
        tip(address(dfx), address(this), 1_000_000e18);
        // Dump DFX to push down the price
        address[] memory path = new address[](2);
        path[0] = Mainnet.DFX;
        path[1] = Mainnet.WETH;

        for (uint i=0; i < 10; i++) {
            sushiRouter.swapExactTokensForTokens(
                100_000e18,
                0,
                path,
                address(this),
                block.timestamp
            );

            cheats.warp(block.timestamp + dfxCadc.POKE_WAIT_PERIOD() + 1);
            twap.update();
            uint256 cadPerDfx = twap.read();
            emit log_uint(cadPerDfx);
        }
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

        accessAdmin.call(
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
        accessAdmin.call(
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
        accessAdmin.call(
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
        accessAdmin.call(
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
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxCadc.POKE_WAIT_PERIOD() + 1);
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
    }

    function testFail_dfxcadc_poke_up_2() public {
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeUp.selector, new bytes(0))
        );
    }

    function test_dfxcadc_poke_down_2() public {
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxCadc.POKE_WAIT_PERIOD() + 1);
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxcadc_poke_down_2() public {
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxcadc_paused_mint() public {
        test_dfxcadc_mint(100e18);
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxcadc_mint(1e18);
    }

    function testFail_dfxcadc_paused_burn() public {
        test_dfxcadc_burn(1e18);
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxcadc_burn(1e18);
    }

    function test_dfxcadc_unpause() public {
        // Contract can be unpaused
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, true)
        );

        cheats.expectRevert("Pausable: paused");
        dfxCadc.mint(100e18);

        // unpause and try again
        accessAdmin.call(
            address(dfxCadc),
            abi.encodeWithSelector(dfxCadc.setPaused.selector, false)
        );
        test_dfxcadc_mint(100e18);
    }

    function test_dfxcadc_mint_burn_spotprice() public {
        assertEq(dfx.balanceOf(address(this)), 0);
        assertEq(cadc.balanceOf(address(this)), 0);

        // Mint + burn one token w/o fees
        test_dfxcadc_burn_no_fee(1e18);

        // Now we go from
        // DFX -> WETH -> USDC @ sushi
        // USDC -> CADC @ dfx
        // And see if we end up with 1 CADC
        address[] memory path = new address[](3);
        path[0] = Mainnet.DFX;
        path[1] = Mainnet.WETH;
        path[2] = Mainnet.USDC;
        uint256 usdcOut = sushiRouter.getAmountsOut(
            dfx.balanceOf(address(this)),
            path
        )[2];
        uint256 cadcOutFromDfx = dfxUsdcCadcA.viewOriginSwap(
            address(usdc),
            address(cadc),
            usdcOut
        );

        uint256 totalCadcOut = cadcOutFromDfx + cadc.balanceOf(address(this));

        assertLe(totalCadcOut, 1.001e18);
        assertGt(totalCadcOut, 0.999e18);
    }
}
