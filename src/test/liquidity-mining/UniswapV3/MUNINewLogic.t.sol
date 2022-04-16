// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import {stdCheats} from "@forge-std/stdlib.sol";

import "../../../ASCUpgradableProxy.sol";

import "../../lib/Address.sol";
import "../../lib/CheatCodes.sol";
import "../../lib/MockToken.sol";
import "../../lib/MockUser.sol";

import "../../../libraries/FixedPoint.sol";

import "../../../liquidity-mining/UniswapV3/MUNILogicV1.sol";
import "../../../liquidity-mining/UniswapV3/MUNINewLogic.sol";


contract MUNINewLogicTest is DSTest, stdCheats {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    MUNILogicV1 muniLogic;

    MUNINewLogic newProxiedMuniLogic = MUNINewLogic(Mainnet.DFX_CAD_CADC_MUNI);
    MUNINewLogic newMuniLogic;
    
    // Mock tokens to be used as UniV3 liquidity pair
    MockToken token0;
    MockToken token1;

    // Mock contract users
    MockUser admin;

    IUniswapV3Pool pool;    

    ASCUpgradableProxy upgradeableProxy = ASCUpgradableProxy(payable(Mainnet.DFX_CAD_CADC_MUNI));

    uint24 public constant fee = 3000;
    int24 tickSpacing;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        admin = new MockUser();
        token0 = new MockToken();
        token1 = new MockToken();

        if (address(token1) < address(token0)) {
            address temp = address(token0);
            token0 = token1;
            token1 = MockToken(temp);
        }


        pool = IUniswapV3Pool(
            IUniswapV3Factory(Mainnet.UNIV3_FACTORY).createPool(
                address(token0),
                address(token1),
                fee
            )
        );
        tickSpacing = pool.tickSpacing();

        /*
            Getting tick from price
            https://ethereum.stackexchange.com/questions/98685/computing-the-uniswap-v3-pair-price-from-q64-96-number
            https://docs.uniswap.org/sdk/guides/fetching-prices
            To get the sqrtPriceX96 from price
            sqrtPriceX96 = sqrt(price) * 2 ** 96
            # divide both sides by 2 ** 96
            sqrtPriceX96 / (2 ** 96) = sqrt(price)
            # square both sides
            (sqrtPriceX96 / (2 ** 96)) ** 2 = price
            # expand the squared fraction
            (sqrtPriceX96 ** 2) / ((2 ** 96) ** 2)  = price
            # multiply the exponents in the denominator to get the final expression
            sqrtRatioX96 ** 2 / 2 ** 192 = price
        */

        uint160 lowerSqrtPriceX96 = FixedPoint
            .fraction(100, 110)
            .sqrt()
            .mul(2**96)
            .decode144();
        uint160 upperSqrtPriceX96 = FixedPoint
            .fraction(110, 100)
            .sqrt()
            .mul(2**96)
            .decode144();

        int24 lowerTick = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);
        lowerTick = lowerTick - (lowerTick % tickSpacing);

        int24 upperTick = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);
        upperTick = upperTick - (upperTick % tickSpacing) + tickSpacing;

        // Initialize at spot price
        uint160 sqrtPriceX96 = uint160(Babylonian.sqrt(1) * 2**96);

        pool.initialize(sqrtPriceX96);
        pool.increaseObservationCardinalityNext(5);

        muniLogic = new MUNILogicV1();
        bytes memory callargs = abi.encodeWithSelector(
            MUNILogicV1.initialize.selector,
            address(this), // owner
            address(pool),
            200, // 2% fee
            lowerTick,
            upperTick
        );
        upgradeableProxy = new ASCUpgradableProxy(
            address(muniLogic),
            address(admin),
            callargs
        );        
    }

    function test_muniproxy_upgrade_with_new_func() public {
        // Deploy new logic
        newMuniLogic = new MUNINewLogic();

        // Point to new logic contract
        cheats.prank(address(admin));
        upgradeableProxy.upgradeTo(address(newMuniLogic));        

        // Wrap new logic around the proxy
        newProxiedMuniLogic = MUNINewLogic(address(upgradeableProxy));

        // Old state
        assertEq(newProxiedMuniLogic.owner(), address(this));
        assertEq(address(newProxiedMuniLogic.pool()), address(pool));
        
        // New function
        // Calling new function through new logic
        string memory newLogicMessage = newProxiedMuniLogic.newLogic();
        assertEq(newLogicMessage, "new logic here");
    }
}
