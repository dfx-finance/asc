// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import {stdCheats} from "@forge-std/stdlib.sol";

import "../../../ASCUpgradableProxy.sol";

import "../../lib/Address.sol";
import "../../lib/CheatCodes.sol";
import "../../lib/MockToken.sol";
import "../../lib/MockUser.sol";

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

    // Mock tokens used for MUNI LP pair
    MockToken token0;
    MockToken token1;

    // Mock contract users
    MockUser admin;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        admin = new MockUser();
        token0 = new MockToken();
        token1 = new MockToken();

        muniLogic = new MUNILogicV1();
        bytes memory callargs = abi.encodeWithSelector(
            muniLogic.initialize.selector
        );

        upgradeableProxy = new ASCUpgradableProxy(
            address(muniLogic),
            address(admin),
            callargs
        );

        muni = MUNILogicV1(Mainnet.DFX_CAD_CADC_MUNI);
    }

}
