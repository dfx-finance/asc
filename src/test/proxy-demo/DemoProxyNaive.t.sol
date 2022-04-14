// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../lib/MockUser.sol";

import "../../proxy-demo/DemoLogic.sol";
import "../../proxy-demo/DemoProxyNaive.sol";


contract DemoProxyNaiveTest is DSTest {    
    DemoLogic logic;
    DemoProxyNaive proxy;

    proxy.setImplementation(address(logic));

    // Mock users so we can have many addresses
    MockUser admin;

    function setUp() public {
        logic = new DemoLogic();
        proxy = new DemoProxy();

        admin = new MockUser();

        // First naive example
        proxy.setImplementation(address(logic));        
    }

    // First naive example
    function test_demoproxy_calls_to_implementation_contract() public {
        assertEq(proxiedLogic.getMagicNumber(), 0x42);
    }
}