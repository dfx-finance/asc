// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../../lib/Address.sol";
import "../../lib/CheatCodes.sol";
import "../../lib/MockToken.sol";

import "../../../libraries/Babylonian.sol";
import "../../../libraries/TickMath.sol";
import "../../../libraries/UniswapV3.sol";

import "../../../interfaces/IUniswapV3.sol";

import "../../../liquidity-mining/UniswapV3/MUNI.sol";


contract MUNITest is DSTest {
    using TickMath for int24;

    MUNI muni;

    MockToken token0;
    MockToken token1;

    IUniswapV3Pool pool;

    INonfungiblePositionManager univ3PosManager =
        INonfungiblePositionManager(Mainnet.UNIV3_POS_MANAGER);

    uint24 public constant fee = 3000;
    
    function setUp() public {
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
        // 0.95
        // uint160 lowerSqrtPriceX96 = uint160(Babylonian.sqrt( * 2**96));
        // int24 lowerTick = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);
        int24 lowerTick = -887220;
        int24 upperTick = 887220;

        // 1.05
        // uint160 upperSqrtPriceX96 = uint160(Babylonian.sqrt(105e16 * 2**96));
        // int24 upperTick = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);

        // Initialize at spot price
        uint160 sqrtPriceX96 = 79239847721719688160768050412; // uint160(Babylonian.sqrt(1 * 2**96));
        pool.initialize(sqrtPriceX96);
        pool.increaseObservationCardinalityNext(5);

        // emit log_uint(sqrtPriceX96);
        // emit log_int(TickMath.getTickAtSqrtRatio(sqrtPriceX96));

        muni = new MUNI(
            address(this), // owner
            address(pool),
            200, // 2% fee
            lowerTick,
            upperTick,
            "MUNI",
            "MUNI"
        );
    }

    function test_muni_mint() public {
        (uint256 amount0, uint256 amount1, uint256 lpAmount) = muni
            .getMintAmounts(10e18, 10e18);
        
        token0.mint(address(this), amount0);
        token0.approve(address(muni), amount0);

        token1.mint(address(this), amount1);
        token1.approve(address(muni), amount1);

        muni.mint(lpAmount, address(this));
    }
}
