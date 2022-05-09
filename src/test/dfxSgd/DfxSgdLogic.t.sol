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

import "../../oracles/DfxSgdTWAP.sol";
import "../../dfxSgd/DfxSgdLogic.sol";
import "../../ASCUpgradableProxy.sol";

import "../../interfaces/IDfxCurve.sol";

contract DfxSgdLogicTest is DSTest, stdCheats {
    // Did it this way to obtain interface
    DfxSgdLogic dfxSgd;

    ASCUpgradableProxy upgradeableProxy;
    DfxSgdLogic logic;
    DfxSgdTWAP twap;

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 xsgd = IERC20(Mainnet.XSGD);
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
    uint256 internal constant XSGD_RATIO = 95e16; // 95%s
    uint256 internal constant POKE_DELTA_RATIO = 1e16; // 1%

    // Used to calculate spot prices
    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(Mainnet.SUSHI_ROUTER);
    IDfxCurve dfxUsdcXsgdA =
        IDfxCurve(0x2baB29a12a9527a179Da88F422cDaaA223A90bD5);

    function setUp() public {
        ml = new MockLogic();
        admin = new MockUser();
        accessAdmin = new MockUser();
        regularUser = new MockUser();
        feeCollector = new MockUser();

        twap = new DfxSgdTWAP(address(this));
        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();

        logic = new DfxSgdLogic();
        bytes memory callargs = abi.encodeWithSelector(
            DfxSgdLogic.initialize.selector,
            "Coin",
            "COIN",
            address(accessAdmin),
            address(feeCollector),
            MINT_BURN_FEE,
            address(twap),
            XSGD_RATIO,
            DFX_RATIO,
            POKE_DELTA_RATIO
        );

        upgradeableProxy = new ASCUpgradableProxy(
            address(logic),
            address(admin),
            callargs
        );

        dfxSgd = DfxSgdLogic(address(upgradeableProxy));

        xsgd.approve(address(dfxSgd), type(uint256).max);
        dfx.approve(address(dfxSgd), type(uint256).max);
    }

    function tipXsgd(address _recipient, uint256 _amount) internal {
        // Tip doesn't work on proxies :\
        cheats.store(
            Mainnet.XSGD,
            keccak256(abi.encode(_recipient, 7)), // slot 7
            bytes32(_amount)
        );
    }

    function testFail_dfxsgd_reinitialize() public {
        admin.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                DfxSgdLogic.initialize.selector,
                "Coin",
                "COIN",
                address(accessAdmin),
                address(feeCollector),
                MINT_BURN_FEE,
                address(twap),
                XSGD_RATIO,
                DFX_RATIO,
                POKE_DELTA_RATIO
            )
        );
    }

    function test_dfxsgd_erc20() public {
        assertEq(dfxSgd.name(), "Coin");
        assertEq(dfxSgd.symbol(), "COIN");
        assertEq(dfxSgd.totalSupply(), 0);

        assertEq(upgradeableProxy.getAdmin(), address(admin));
        assertTrue(dfxSgd.hasRole(dfxSgd.SUDO_ROLE(), address(accessAdmin)));
        assertTrue(dfxSgd.hasRole(dfxSgd.MARKET_MAKER_ROLE(), address(accessAdmin)));
    }

    function test_dfxsgd_access_control() public {
        MockUser newUser = new MockUser();

        assertTrue(
            !dfxSgd.hasRole(dfxSgd.MARKET_MAKER_ROLE(), address(newUser))
        );
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.grantRole.selector,
                dfxSgd.MARKET_MAKER_ROLE(),
                address(newUser)
            )
        );
        assertTrue(
            dfxSgd.hasRole(dfxSgd.MARKET_MAKER_ROLE(), address(newUser))
        );

        assertTrue(!dfxSgd.hasRole(dfxSgd.SUDO_ROLE(), address(newUser)));
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.grantRole.selector,
                dfxSgd.SUDO_ROLE(),
                address(newUser)
            )
        );
        assertTrue(dfxSgd.hasRole(dfxSgd.SUDO_ROLE(), address(newUser)));
    }

    function testFail_dfxsgd_access_pokedelta() public {
        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.setPokeDelta.selector, 1e15)
        );
    }

    function testFail_dfxsgd_access_pokeUp() public {
        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeUp.selector)
        );
    }

    function testFail_dfxsgd_access_pokeDown() public {
        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeDown.selector)
        );
    }

    function testFail_dfxsgd_access_setdfxsgdtwap() public {
        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.setDfxSgdTwap.selector, address(0))
        );
    }

    function testFail_dfxsgd_access_recoverERC20() public {
        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.recoverERC20.selector, Mainnet.DAI)
        );
    }

    function testFail_dfxsgd_access_execute() public {
        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.execute.selector,
                address(ml),
                abi.encodeWithSelector(ml.doSomething.selector)
            )
        );
    }

    function test_dfxsgd_access_execute() public {
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.grantRole.selector,
                dfxSgd.CR_DEFENDER(),
                address(regularUser)
            )
        );

        regularUser.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.execute.selector,
                address(ml),
                abi.encodeWithSelector(ml.doSomething.selector)
            )
        );
    }

    function test_dfxsgd_get_underlyings() public {
        (uint256 xsgdAmount, uint256 dfxAmount) = dfxSgd.getUnderlyings(
            100e18
        );
        uint256 sgdPerDfx = twap.read();
        uint256 sum = xsgdAmount + ((dfxAmount * sgdPerDfx) / 1e18);

        // Should add to 100 SGD
        // Assume 1 XSGD = 1 SGD
        assertLe(sum, 100e18);
        assertGt(sum, 9999e16);
    }

    function test_dfxsgd_mint(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e6);
        cheats.assume(lpAmount < 1_000_000_000e18);

        (uint256 xsgdAmount, uint256 dfxAmount) = dfxSgd.getUnderlyings(
            lpAmount
        );

        tipXsgd(address(this), xsgdAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);
        
        dfxSgd.mint(lpAmount);
        uint256 fee = (lpAmount * dfxSgd.mintBurnFee()) / 1e18;
        assertEq(dfxSgd.balanceOf(address(this)), lpAmount - fee);
    }

    function test_dfxsgd_mint_no_fees(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e5);
        cheats.assume(lpAmount < 1_000_000_000e18);

        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.grantRole.selector,
                dfxSgd.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        (uint256 xsgdAmount, uint256 dfxAmount) = dfxSgd.getUnderlyings(
            lpAmount
        );

        tipXsgd(address(this), xsgdAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);

        dfxSgd.mint(lpAmount);
        assertEq(dfxSgd.balanceOf(address(this)), lpAmount);
    }

    function test_dfxsgd_burn(uint256 lpAmount) public {
        test_dfxsgd_mint_no_fees(lpAmount);
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(
                dfxSgd.revokeRole.selector,
                dfxSgd.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        // Burn
        dfxSgd.burn(lpAmount);

        // Mint + burn fee
        uint256 _fee = (lpAmount * dfxSgd.mintBurnFee()) / 1e18;
        (uint256 xsgdAmount, uint256 dfxAmount) = dfxSgd.getUnderlyings(
            lpAmount - _fee
        );

        assertEq(dfxSgd.balanceOf(address(feeCollector)), _fee);
        assertEq(xsgd.balanceOf(address(this)), xsgdAmount);
        assertEq(dfx.balanceOf(address(this)), dfxAmount);
    }

    function test_dfxsgd_burn_no_fee(uint256 lpAmount) public {
        test_dfxsgd_mint_no_fees(lpAmount);

        dfxSgd.burn(lpAmount);
        (uint256 xsgdAmount, uint256 dfxAmount) = dfxSgd.getUnderlyings(
            lpAmount
        );

        assertEq(xsgd.balanceOf(address(this)), xsgdAmount);
        assertEq(dfx.balanceOf(address(this)), dfxAmount);
    }

    function test_dfxsgd_poke_up() public {
        uint256 xsgdR0 = dfxSgd.xsgdRatio();
        uint256 dfxR0 = dfxSgd.dfxRatio();

        (uint256 xsgdAmount0, uint256 dfxAmount0) = dfxSgd.getUnderlyings(
            1e18
        );
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeUp.selector, new bytes(0))
        );
        (uint256 xsgdAmount1, uint256 dfxAmount1) = dfxSgd.getUnderlyings(
            1e18
        );

        uint256 xsgdR1 = dfxSgd.xsgdRatio();
        uint256 dfxR1 = dfxSgd.dfxRatio();

        assertLt(xsgdAmount1, xsgdAmount0);
        assertGt(dfxAmount1, dfxAmount0);

        assertLt(xsgdR1, xsgdR0);
        assertGt(dfxR1, dfxR0);
    }
    
    function test_dfxsgd_poke_down() public {
        uint256 xsgdR0 = dfxSgd.xsgdRatio();
        uint256 dfxR0 = dfxSgd.dfxRatio();

        (uint256 xsgdAmount0, uint256 dfxAmount0) = dfxSgd.getUnderlyings(
            1e18
        );
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeDown.selector, new bytes(0))
        );
        (uint256 xsgdAmount1, uint256 dfxAmount1) = dfxSgd.getUnderlyings(
            1e18
        );

        uint256 xsgdR1 = dfxSgd.xsgdRatio();
        uint256 dfxR1 = dfxSgd.dfxRatio();

        assertGt(xsgdAmount1, xsgdAmount0);
        assertLt(dfxAmount1, dfxAmount0);

        assertGt(xsgdR1, xsgdR0);
        assertLt(dfxR1, dfxR0);
    }

    function test_dfxsgd_poke_up_2() public {
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeUp.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxSgd.POKE_WAIT_PERIOD() + 1);
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeUp.selector, new bytes(0))
        );
    }

    function testFail_dfxsgd_poke_up_2() public {
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeUp.selector, new bytes(0))
        );
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeUp.selector, new bytes(0))
        );
    }

    function test_dfxsgd_poke_down_2() public {
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeDown.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxSgd.POKE_WAIT_PERIOD() + 1);
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxsgd_poke_down_2() public {
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeDown.selector, new bytes(0))
        );
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxsgd_paused_mint() public {
        test_dfxsgd_mint(100e18);
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxsgd_mint(1e18);
    }

    function testFail_dfxsgd_paused_burn() public {
        test_dfxsgd_burn(1e18);
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxsgd_burn(1e18);
    }

    function test_dfxsgd_unpause() public {
        // Contract can be unpaused
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.setPaused.selector, true)
        );

        cheats.expectRevert("Pausable: paused");
        dfxSgd.mint(100e18);

        // unpause and try again
        accessAdmin.call(
            address(dfxSgd),
            abi.encodeWithSelector(dfxSgd.setPaused.selector, false)
        );
        test_dfxsgd_mint(100e18);
    }

    function test_dfxsgd_mint_burn_spotprice() public {
        assertEq(dfx.balanceOf(address(this)), 0);
        assertEq(xsgd.balanceOf(address(this)), 0);

        // Mint + burn one token w/o fees
        test_dfxsgd_burn_no_fee(1e6);

        // Now we go from
        // DFX -> WETH -> USDC @ sushi
        // USDC -> XSGD @ dfx
        // And see if we end up with 1 XSGD
        address[] memory path = new address[](3);
        path[0] = Mainnet.DFX;
        path[1] = Mainnet.WETH;
        path[2] = Mainnet.USDC;
        uint256 usdcOut = sushiRouter.getAmountsOut(
            dfx.balanceOf(address(this)),
            path
        )[2];
        uint256 xsgdOutFromDfx = dfxUsdcXsgdA.viewOriginSwap(
            address(usdc),
            address(xsgd),
            usdcOut
        );

        emit log_uint(xsgd.balanceOf(address(this)));
        emit log_uint(xsgdOutFromDfx);

        uint256 totalXsgdOut = xsgdOutFromDfx + xsgd.balanceOf(address(this));

        emit log_uint(totalXsgdOut);

        // assertLe(totalXsgdOut, 1.001e18);
        // assertGt(totalXsgdOut, 0.999e18);
    }
}
