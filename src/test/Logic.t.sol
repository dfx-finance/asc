// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./lib/MockToken.sol";
import "./lib/MockUser.sol";

import "../Logic.sol";
import "../UpgradableProxy.sol";

contract LogicTest is DSTest {
    // Did it this way to obtain interface
    Logic proxy;

    UpgradableProxy upgradeableProxy;
    Logic logic;

    MockToken stablecoin;
    MockToken volatileToken;

    MockUser admin;
    MockUser feeCollector;

    function setUp() public {
        stablecoin = new MockToken();
        volatileToken = new MockToken();

        admin = new MockUser();
        feeCollector = new MockUser();

        address[] memory underlying = new address[](2);
        underlying[0] = address(stablecoin);
        underlying[1] = address(volatileToken);

        uint256[] memory backingRatio = new uint256[](2);
        backingRatio[0] = 5e17;
        backingRatio[1] = 5e17;

        int256[] memory pokeDelta = new int256[](2);
        pokeDelta[0] = -1e16;
        pokeDelta[1] = 1e16;

        logic = new Logic();
        bytes memory callargs = abi.encodeWithSelector(
            Logic.initialize.selector,
            "Coin",
            "COIN",
            address(admin),
            address(feeCollector),
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
    }

    function test_proxy_erc20() public {
        assertEq(proxy.name(), "Coin");
        assertEq(proxy.symbol(), "COIN");
    }
}
