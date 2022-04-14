// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import {stdCheats} from "@forge-std/stdlib.sol";

import "../../../ASCUpgradableProxy.sol";

import "../../lib/Address.sol";
import "../../lib/CheatCodes.sol";
import "../../lib/MockToken.sol";

import "../../../libraries/Babylonian.sol";
import "../../../libraries/TickMath.sol";
import "../../../libraries/UniswapV3.sol";
import "../../../libraries/FixedPoint.sol";

import "../../../interfaces/IUniswapV3.sol";

import "../../../liquidity-mining/UniswapV3/MUNILogicV1.sol";

contract MUNITest is DSTest, stdCheats {
    // get interface as done in dfxCad's tests
    MUNILogicV1 muni = MUNILogicV1(Mainnet.DFX_CAD_CADC_MUNI);
    MUNILogicV1 muniLogic;

    ASCUpgradableProxy upgradeableProxy = ASCUpgradableProxy(payable(Mainnet.DFX_CAD_CADC_MUNI));

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        muniLogic = new MUNILogicV1();
        muni = MUNILogicV1(Mainnet.DFX_CAD_CADC_MUNI);
    }

}
