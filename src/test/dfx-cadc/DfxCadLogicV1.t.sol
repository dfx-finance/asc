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
import "../../dfx-cadc/DfxCadLogicV1.sol";
import "../../ASCUpgradableProxy.sol";

import "../../interfaces/IDfxCurve.sol";

contract DfxCadLogicV1Test is DSTest, stdCheats {
    // Did it this way to obtain interface
    DfxCadLogicV1 dfxCad = DfxCadLogicV1(Mainnet.DFX_CAD);
    DfxCadLogicV1 dfxCadLogic;
    
    ASCUpgradableProxy upgradeableProxy = ASCUpgradableProxy(payable(Mainnet.DFX_CAD));

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        dfxCadLogic = new DfxCadLogicV1();
        dfxCad = DfxCadLogicV1(Mainnet.DFX_CAD);
    }

    function test_dfxcad_name_change() public {
        bytes memory callargs = abi.encodeWithSelector(
            DfxCadLogicV1.initialize.selector
        );
        cheats.prank(Mainnet.DFX_CAD_GOV);
        upgradeableProxy.upgradeToAndCall(address(dfxCadLogic), callargs);

        assertEq(dfxCad.name(), "dfxCAD");
        assertEq(dfxCad.symbol(), "dfxCAD");

        cheats.expectRevert("no-reinit");
        dfxCad.initialize();
    }
}
