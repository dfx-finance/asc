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

import "../../oracles/DfxEurTWAP.sol";
import "../../dfxEur/DfxEurLogic.sol";
import "../../ASCUpgradableProxy.sol";

import "../../interfaces/IDfxCurve.sol";

contract DfxEurLogicTest is DSTest, stdCheats {
    // Did it this way to obtain interface
    DfxEurLogic dfxEur;

    ASCUpgradableProxy upgradeableProxy;
    DfxEurLogic logic;
    DfxEurTWAP twap;

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 eurs = IERC20(Mainnet.EURS);
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
    uint256 internal constant EURS_RATIO = 95e16; // 95%s
    uint256 internal constant POKE_DELTA_RATIO = 1e16; // 1%

    // Used to calculate spot prices
    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(Mainnet.SUSHI_ROUTER);
    IDfxCurve dfxUsdcEursA =
        IDfxCurve(0x1a4Ffe0DCbDB4d551cfcA61A5626aFD190731347);

    function setUp() public {
        ml = new MockLogic();
        admin = new MockUser();
        accessAdmin = new MockUser();
        regularUser = new MockUser();
        feeCollector = new MockUser();

        twap = new DfxEurTWAP(address(this));
        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();

        logic = new DfxEurLogic();
        bytes memory callargs = abi.encodeWithSelector(
            DfxEurLogic.initialize.selector,
            "Coin",
            "COIN",
            address(accessAdmin),
            address(feeCollector),
            MINT_BURN_FEE,
            address(twap),
            EURS_RATIO,
            DFX_RATIO,
            POKE_DELTA_RATIO
        );

        upgradeableProxy = new ASCUpgradableProxy(
            address(logic),
            address(admin),
            callargs
        );

        dfxEur = DfxEurLogic(address(upgradeableProxy));

        eurs.approve(address(dfxEur), type(uint256).max);
        dfx.approve(address(dfxEur), type(uint256).max);
    }

    function tipEurs(address _recipient, uint256 _amount) internal {
        // Tip doesn't work on proxies :\
        cheats.store(
            Mainnet.EURS,
            keccak256(abi.encode(_recipient, 0)), // slot 0
            bytes32(_amount)
        );
    }

    function testFail_dfxeur_reinitialize() public {
        admin.call(
            address(dfxEur),
            abi.encodeWithSelector(
                DfxEurLogic.initialize.selector,
                "Coin",
                "COIN",
                address(accessAdmin),
                address(feeCollector),
                MINT_BURN_FEE,
                address(twap),
                EURS_RATIO,
                DFX_RATIO,
                POKE_DELTA_RATIO
            )
        );
    }

    function test_dfxeur_erc20() public {
        assertEq(dfxEur.name(), "Coin");
        assertEq(dfxEur.symbol(), "COIN");
        assertEq(dfxEur.totalSupply(), 0);

        assertEq(upgradeableProxy.getAdmin(), address(admin));
        assertTrue(dfxEur.hasRole(dfxEur.SUDO_ROLE(), address(accessAdmin)));
        assertTrue(dfxEur.hasRole(dfxEur.MARKET_MAKER_ROLE(), address(accessAdmin)));
    }

    function test_dfxeur_access_control() public {
        MockUser newUser = new MockUser();

        assertTrue(
            !dfxEur.hasRole(dfxEur.MARKET_MAKER_ROLE(), address(newUser))
        );
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.grantRole.selector,
                dfxEur.MARKET_MAKER_ROLE(),
                address(newUser)
            )
        );
        assertTrue(
            dfxEur.hasRole(dfxEur.MARKET_MAKER_ROLE(), address(newUser))
        );

        assertTrue(!dfxEur.hasRole(dfxEur.SUDO_ROLE(), address(newUser)));
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.grantRole.selector,
                dfxEur.SUDO_ROLE(),
                address(newUser)
            )
        );
        assertTrue(dfxEur.hasRole(dfxEur.SUDO_ROLE(), address(newUser)));
    }

    function testFail_dfxeur_access_pokedelta() public {
        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.setPokeDelta.selector, 1e15)
        );
    }

    function testFail_dfxeur_access_pokeUp() public {
        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeUp.selector)
        );
    }

    function testFail_dfxeur_access_pokeDown() public {
        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeDown.selector)
        );
    }

    function testFail_dfxeur_access_setdfxeurtwap() public {
        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.setDfxEurTwap.selector, address(0))
        );
    }

    function testFail_dfxeur_access_recoverERC20() public {
        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.recoverERC20.selector, Mainnet.DAI)
        );
    }

    function testFail_dfxeur_access_execute() public {
        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.execute.selector,
                address(ml),
                abi.encodeWithSelector(ml.doSomething.selector)
            )
        );
    }

    function test_dfxeur_access_execute() public {
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.grantRole.selector,
                dfxEur.CR_DEFENDER(),
                address(regularUser)
            )
        );

        regularUser.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.execute.selector,
                address(ml),
                abi.encodeWithSelector(ml.doSomething.selector)
            )
        );
    }

    function test_dfxeur_get_underlyings() public {
        (uint256 eursAmount, uint256 dfxAmount) = dfxEur.getUnderlyings(
            100e18
        );
        uint256 eurPerDfx = twap.read();
        // emit log_uint(eurPerDfx);
        emit log_uint(((dfxAmount * eurPerDfx) / 1e18));
        emit log_uint(eursAmount);
        uint256 sum = eursAmount + ((dfxAmount * eurPerDfx) / 1e18);

        // Should add to 100 EUR
        // Assume 1 EURS = 1 EUR
        assertLe(sum, 100e18);
        assertGt(sum, 9999e16);
    }

    function test_dfxeur_mint(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e6);
        cheats.assume(lpAmount < 1_000_000_000e18);

        (uint256 eursAmount, uint256 dfxAmount) = dfxEur.getUnderlyings(
            lpAmount
        );

        tipEurs(address(this), eursAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);
        
        dfxEur.mint(lpAmount);
        uint256 fee = (lpAmount * dfxEur.mintBurnFee()) / 1e18;
        assertEq(dfxEur.balanceOf(address(this)), lpAmount - fee);
    }

    function test_dfxeur_mint_no_fees(uint256 lpAmount) public {
        cheats.assume(lpAmount > 1e6);
        cheats.assume(lpAmount < 1_000_000_000e18);

        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.grantRole.selector,
                dfxEur.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        (uint256 eursAmount, uint256 dfxAmount) = dfxEur.getUnderlyings(
            lpAmount
        );

        tipEurs(address(this), eursAmount);
        tip(Mainnet.DFX, address(this), dfxAmount);

        dfxEur.mint(lpAmount);
        assertEq(dfxEur.balanceOf(address(this)), lpAmount);
    }

    function test_dfxeur_burn(uint256 lpAmount) public {
        test_dfxeur_mint_no_fees(lpAmount);
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(
                dfxEur.revokeRole.selector,
                dfxEur.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        // Burn
        dfxEur.burn(lpAmount);

        // Mint + burn fee
        uint256 _fee = (lpAmount * dfxEur.mintBurnFee()) / 1e18;
        (uint256 eursAmount, uint256 dfxAmount) = dfxEur.getUnderlyings(
            lpAmount - _fee
        );

        assertEq(dfxEur.balanceOf(address(feeCollector)), _fee);
        assertEq(eurs.balanceOf(address(this)), eursAmount);
        assertEq(dfx.balanceOf(address(this)), dfxAmount);
    }

    function test_dfxeur_burn_no_fee(uint256 lpAmount) public {
        test_dfxeur_mint_no_fees(lpAmount);

        dfxEur.burn(lpAmount);
        (uint256 eursAmount, uint256 dfxAmount) = dfxEur.getUnderlyings(
            lpAmount
        );

        assertEq(eurs.balanceOf(address(this)), eursAmount);
        assertEq(dfx.balanceOf(address(this)), dfxAmount);
    }

    function test_dfxeur_poke_up() public {
        uint256 eursR0 = dfxEur.eursRatio();
        uint256 dfxR0 = dfxEur.dfxRatio();

        (uint256 eursAmount0, uint256 dfxAmount0) = dfxEur.getUnderlyings(
            1e18
        );
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeUp.selector, new bytes(0))
        );
        (uint256 eursAmount1, uint256 dfxAmount1) = dfxEur.getUnderlyings(
            1e18
        );

        uint256 eursR1 = dfxEur.eursRatio();
        uint256 dfxR1 = dfxEur.dfxRatio();

        assertLt(eursAmount1, eursAmount0);
        assertGt(dfxAmount1, dfxAmount0);

        assertLt(eursR1, eursR0);
        assertGt(dfxR1, dfxR0);
    }
    
    function test_dfxeur_poke_down() public {
        uint256 eursR0 = dfxEur.eursRatio();
        uint256 dfxR0 = dfxEur.dfxRatio();

        (uint256 eursAmount0, uint256 dfxAmount0) = dfxEur.getUnderlyings(
            1e18
        );
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeDown.selector, new bytes(0))
        );
        (uint256 eursAmount1, uint256 dfxAmount1) = dfxEur.getUnderlyings(
            1e18
        );

        uint256 eursR1 = dfxEur.eursRatio();
        uint256 dfxR1 = dfxEur.dfxRatio();

        assertGt(eursAmount1, eursAmount0);
        assertLt(dfxAmount1, dfxAmount0);

        assertGt(eursR1, eursR0);
        assertLt(dfxR1, dfxR0);
    }

    function test_dfxeur_poke_up_2() public {
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeUp.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxEur.POKE_WAIT_PERIOD() + 1);
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeUp.selector, new bytes(0))
        );
    }

    function testFail_dfxeur_poke_up_2() public {
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeUp.selector, new bytes(0))
        );
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeUp.selector, new bytes(0))
        );
    }

    function test_dfxeur_poke_down_2() public {
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeDown.selector, new bytes(0))
        );
        cheats.warp(block.timestamp + dfxEur.POKE_WAIT_PERIOD() + 1);
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxeur_poke_down_2() public {
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeDown.selector, new bytes(0))
        );
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.pokeDown.selector, new bytes(0))
        );
    }

    function testFail_dfxeur_paused_mint() public {
        test_dfxeur_mint(100e18);
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxeur_mint(1e18);
    }

    function testFail_dfxeur_paused_burn() public {
        test_dfxeur_burn(1e18);
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.setPaused.selector, true)
        );
        cheats.expectRevert("Pausable: paused");
        test_dfxeur_burn(1e18);
    }

    function test_dfxeur_unpause() public {
        // Contract can be unpaused
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.setPaused.selector, true)
        );

        cheats.expectRevert("Pausable: paused");
        dfxEur.mint(100e18);

        // unpause and try again
        accessAdmin.call(
            address(dfxEur),
            abi.encodeWithSelector(dfxEur.setPaused.selector, false)
        );
        test_dfxeur_mint(100e18);
    }

    function test_dfxeur_mint_burn_spotprice() public {
        assertEq(dfx.balanceOf(address(this)), 0);
        assertEq(eurs.balanceOf(address(this)), 0);

        // Mint + burn one token w/o fees
        test_dfxeur_burn_no_fee(1e18);

        // Now we go from
        // DFX -> WETH -> USDC @ sushi
        // USDC -> EURS @ dfx
        // And see if we end up with 1 EURS
        address[] memory path = new address[](3);
        path[0] = Mainnet.DFX;
        path[1] = Mainnet.WETH;
        path[2] = Mainnet.USDC;
        uint256 usdcOut = sushiRouter.getAmountsOut(
            dfx.balanceOf(address(this)),
            path
        )[2];
        uint256 eursOutFromDfx = dfxUsdcEursA.viewOriginSwap(
            address(usdc),
            address(eurs),
            usdcOut
        );

        uint256 totalEursOut = eursOutFromDfx + eurs.balanceOf(address(this));

        assertLe(totalEursOut, 1.001e18);
        assertGt(totalEursOut, 0.999e18);
    }
}
