// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./lib/MockToken.sol";
import "./lib/MockUser.sol";
import "./lib/CheatCodes.sol";

import "../Logic.sol";
import "../UpgradableProxy.sol";

contract LogicTest is DSTest {
    // Did it this way to obtain interface
    Logic proxy;

    UpgradableProxy upgradeableProxy;
    Logic logic;

    MockToken stablecoin;
    MockToken volatileToken;

    // Mock users so we can have many addresses
    MockUser admin;
    MockUser sudo;
    MockUser feeCollector;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    // MINT BURN FEE
    // 0.5%
    uint256 constant internal MINT_BURN_FEE = 5e15;

    function setUp() public {
        stablecoin = new MockToken();
        volatileToken = new MockToken();

        admin = new MockUser();
        sudo = new MockUser();
        feeCollector = new MockUser();

        address[] memory underlying = new address[](2);
        underlying[0] = address(stablecoin);
        underlying[1] = address(volatileToken);

        uint256[] memory backingRatio = new uint256[](2);
        backingRatio[0] = 99e16;
        backingRatio[1] = 1e16;

        int256[] memory pokeDelta = new int256[](2);
        pokeDelta[0] = -1e16;
        pokeDelta[1] = 1e16;

        logic = new Logic();
        bytes memory callargs = abi.encodeWithSelector(
            Logic.initialize.selector,
            "Coin",
            "COIN",
            address(sudo),
            address(feeCollector),
            MINT_BURN_FEE,
            underlying,
            backingRatio,
            pokeDelta
        );

        upgradeableProxy = new UpgradableProxy(
            address(logic),
            address(admin),
            callargs
        );

        proxy = Logic(address(upgradeableProxy));

        // If block.timestamp is 0 just set it to sometime in 2022
        if (block.timestamp == 0) {
            cheats.warp(1646765810);
        }
    }

    // Should only be able to initialize once
    function testFail_reinitialize() public {
        address[] memory underlying = new address[](2);
        underlying[0] = address(stablecoin);
        underlying[1] = address(volatileToken);

        uint256[] memory backingRatio = new uint256[](2);
        backingRatio[0] = 99e16;
        backingRatio[1] = 1e16;

        int256[] memory pokeDelta = new int256[](2);
        pokeDelta[0] = -1e16;
        pokeDelta[1] = 1e16;

        admin.call(
            address(proxy),
            abi.encodeWithSelector(
                logic.initialize.selector,
                "Coin",
                "COIN",
                MINT_BURN_FEE, // 0.5% mint burn
                address(sudo),
                address(feeCollector),
                underlying,
                backingRatio,
                pokeDelta
            )
        );
    }

    function test_proxy_erc20() public {
        assertEq(proxy.name(), "Coin");
        assertEq(proxy.symbol(), "COIN");
        assertEq(proxy.totalSupply(), 0);

        assertEq(upgradeableProxy.getAdmin(), address(admin));
        assertTrue(proxy.hasRole(proxy.SUDO_ROLE(), address(sudo)));
        assertTrue(proxy.hasRole(proxy.MARKET_MAKER_ROLE(), address(sudo)));
    }

    function test_access_control() public {
        MockUser newUser = new MockUser();

        assertTrue(!proxy.hasRole(proxy.MARKET_MAKER_ROLE(), address(newUser)));
        sudo.call(
            address(proxy),
            abi.encodeWithSelector(
                proxy.grantRole.selector,
                proxy.MARKET_MAKER_ROLE(),
                address(newUser)
            )
        );
        assertTrue(proxy.hasRole(proxy.MARKET_MAKER_ROLE(), address(newUser)));

        assertTrue(!proxy.hasRole(proxy.SUDO_ROLE(), address(newUser)));
        sudo.call(
            address(proxy),
            abi.encodeWithSelector(
                proxy.grantRole.selector,
                proxy.SUDO_ROLE(),
                address(newUser)
            )
        );
        assertTrue(proxy.hasRole(proxy.SUDO_ROLE(), address(newUser)));
    }

    function test_mint_fee() public {
        assertEq(proxy.balanceOf(address(this)), 0);

        stablecoin.mint(address(this), 99e18);
        volatileToken.mint(address(this), 1e18);

        stablecoin.approve(address(proxy), type(uint256).max);
        volatileToken.approve(address(proxy), type(uint256).max);

        proxy.mint(100e18);

        assertEq(stablecoin.balanceOf(address(this)), 0);
        assertEq(volatileToken.balanceOf(address(this)), 0);

        // 0.5% fee
        assertEq(proxy.balanceOf(address(this)), 995e17);
    }

    function test_burn_fee() public {
        // Have 99.5 tokens
        test_mint_fee();

        assertEq(stablecoin.balanceOf(address(this)), 0);
        assertEq(volatileToken.balanceOf(address(this)), 0);

        // How much do we get burning 10 tokens?
        // Multiply by 0.995 to get actual output
        uint256[] memory amounts = proxy.getMintUnderlyings(10e18);
        amounts[0] = amounts[0] * 995 / 1000;
        amounts[1] = amounts[1] * 995 / 1000;

        // Burn
        proxy.burn(10e18);

        assertEq(stablecoin.balanceOf(address(this)), amounts[0]);
        assertEq(volatileToken.balanceOf(address(this)), amounts[1]);
    }

    function test_mint_no_fee() public {
        assertEq(proxy.balanceOf(address(this)), 0);

        stablecoin.mint(address(this), 99e18);
        volatileToken.mint(address(this), 1e18);

        stablecoin.approve(address(proxy), type(uint256).max);
        volatileToken.approve(address(proxy), type(uint256).max);

        sudo.call(
            address(proxy),
            abi.encodeWithSelector(
                proxy.grantRole.selector,
                proxy.MARKET_MAKER_ROLE(),
                address(this)
            )
        );

        proxy.mint(100e18);

        assertEq(stablecoin.balanceOf(address(this)), 0);
        assertEq(volatileToken.balanceOf(address(this)), 0);

        // No fee
        assertEq(proxy.balanceOf(address(this)), 100e18);
    }

    function test_burn_no_fee() public {
        test_mint_no_fee();

        assertEq(stablecoin.balanceOf(address(this)), 0);
        assertEq(volatileToken.balanceOf(address(this)), 0);

        uint256[] memory amounts = proxy.getMintUnderlyings(10e18);

        proxy.burn(10e18);

        assertEq(stablecoin.balanceOf(address(this)), amounts[0]);
        assertEq(volatileToken.balanceOf(address(this)), amounts[1]);
    }

    function test_poke_up_underlyings() public {
        uint256[] memory amounts0 = proxy.getMintUnderlyings(1e18);
        test_poke_up();
        uint256[] memory amounts1 = proxy.getMintUnderlyings(1e18);

        // 0 is stable
        // 1 is volatile

        // Poke up = less dependent on stablecoins
        assertLt(amounts1[0], amounts0[0]);
        assertGt(amounts1[1], amounts0[1]);
    }

    function test_poke_down_underlyings() public {
        uint256[] memory amounts0 = proxy.getMintUnderlyings(1e18);
        test_poke_down();
        uint256[] memory amounts1 = proxy.getMintUnderlyings(1e18);

        // 0 is stable
        // 1 is volatile

        // Poke down = more dependent on stablecoins
        assertGt(amounts1[0], amounts0[0]);
        assertLt(amounts1[1], amounts0[1]);
    }

    function test_poke_up() public {
        sudo.call(
            address(proxy),
            abi.encodeWithSelector(proxy.pokeUp.selector)
        );
    }

    function test_poke_down() public {
        sudo.call(
            address(proxy),
            abi.encodeWithSelector(proxy.pokeDown.selector)
        );
    }

    function test_poke_up_2() public {
        test_poke_up();
        cheats.warp(block.timestamp + proxy.POKE_WAIT_PERIOD() + 60);
        test_poke_up();
    }

    function test_poke_down_2() public {
        test_poke_down();
        cheats.warp(block.timestamp + proxy.POKE_WAIT_PERIOD() + 60);
        test_poke_down();
    }

    function testFail_poke_up_2() public {
        // Need to wait POKE_WAIT_PERIOD between each poke
        test_poke_up();
        test_poke_up();
    }

    function testFail_poke_down_2() public {
        // Need to wait POKE_WAIT_PERIOD between each poke
        test_poke_down();
        test_poke_down();
    }
}
