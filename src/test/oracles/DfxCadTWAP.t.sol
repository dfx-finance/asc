// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import "../../interfaces/IChainLinkOracle.sol";
import "../../oracles/DfxCadTWAP.sol";

contract DfxCadTWAPTest is DSTest {
    DfxCadTWAP twap;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        twap = new DfxCadTWAP();
    }

    function test_dfxcadtwap() public {
        uint256 cadcPerDfx = twap.read();
        assertEq(cadcPerDfx, 0);

        cheats.warp(block.timestamp + 6 hours + 10 minutes);
        cheats.prank(address(this), address(this));
        twap.update();
        cheats.warp(block.timestamp + 6 hours + 10 minutes);
        cheats.prank(address(this), address(this));
        twap.update();

        cadcPerDfx = twap.read();
        assertGt(cadcPerDfx, 0);
    }
}
