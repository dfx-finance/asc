// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../../lib/Address.sol";
import "../../lib/CheatCodes.sol";
import "../../lib/MockToken.sol";

import "../../../libraries/Babylonian.sol";
import "../../../libraries/TickMath.sol";
import "../../../libraries/UniswapV3.sol";
import "../../../libraries/FixedPoint.sol";

import "../../../interfaces/IUniswapV3.sol";

import "../../../liquidity-mining/UniswapV3/MUNI.sol";

contract MUNITest is DSTest {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    using TickMath for int24;

    MUNI muni;

    MockToken token0;
    MockToken token1;

    IUniswapV3Pool pool;

    INonfungiblePositionManager univ3PosManager =
        INonfungiblePositionManager(Mainnet.UNIV3_POS_MANAGER);

    uint24 public constant fee = 3000;
    int24 tickSpacing;

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

    function test_pool_nftpositionmanager() public {
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

        token0.mint(address(this), 10e18);
        token1.mint(address(this), 10e18);

        token0.approve(address(univ3PosManager), 10e18);
        token1.approve(address(univ3PosManager), 10e18);

        univ3PosManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: fee,
                tickLower: lowerTick,
                tickUpper: upperTick,
                amount0Desired: 10e18,
                amount1Desired: 10e18,
                amount0Min: 0e18,
                amount1Min: 0e18,
                recipient: address(this),
                deadline: block.timestamp + 1
            })
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
