// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../lib/MockUser.sol";

import "../../proxy-demo/DemoLogic.sol";
import "../../ASCUpgradableProxy.sol";



contract DemoProxyTest is DSTest {
    // Did it this way to obtain interface, as per dfxCAD tests
    DemoLogic proxiedLogic;    
    
    ASCUpgradableProxy upgradeableProxy;
    DemoLogic logic;

    // Mock users so we can have many addresses
    MockUser admin;

    function setUp() public {
        logic = new DemoLogic();
        admin = new MockUser();
        
        // Using Kendrick's UpgradableProxy wrapper
        bytes memory callargs = abi.encodeWithSelector(DemoLogic.initialize.selector);
        upgradeableProxy = new ASCUpgradableProxy(
            address(logic),
            address(admin),
            callargs
        );

        proxiedLogic = DemoLogic(address(upgradeableProxy));
    }

    // Using Kendrick's UpgradableProxy wrapper
    function test_demoproxy_calls_to_implementation_contract() public {
        assertEq(proxiedLogic.getMagicNumber(), 0x42);

    }
}