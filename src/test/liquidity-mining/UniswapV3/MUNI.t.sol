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
    MUNI muni;

    MockToken tokenA;
    MockToken tokenB;

    IUniswapV3Pool pool;

    INonfungiblePositionManager univ3PosManager = INonfungiblePositionManager(Mainnet.UNIV3_POS_MANAGER);

    uint24 public constant fee = 3000;

    function setUp() public {
        tokenA = new MockToken();
        tokenB = new MockToken();

        pool = IUniswapV3Pool(
            IUniswapV3Factory(Mainnet.UNIV3_FACTORY).createPool(
                address(tokenA),
                address(tokenB),
                fee
            )
        );

        tokenA.mint(address(this), 100e18);
        tokenB.mint(address(this), 100e18);

        tokenA.approve(address(univ3PosManager), type(uint256).max);
        tokenB.approve(address(univ3PosManager), type(uint256).max);

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
        uint160 lowerSqrtPriceX96 = uint160(Babylonian.sqrt(95e16) * 2**96);
        int24 lowerTick = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);

        // 1.05
        uint160 upperSqrtPriceX96 = uint160(Babylonian.sqrt(105e16) * 2**96);
        int24 upperTick = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);

        // Spot price
        uint160 sqrtPriceX96 = uint160(Babylonian.sqrt(100e16) * 2**96);
        pool.initialize(sqrtPriceX96);

        // Mint tokens
        univ3PosManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: fee,
                tickLower: lowerTick,
                tickUpper: upperTick,
                amount0Desired: 10e18,
                amount1Desired: 10e18,
                amount0Min: 1e18,
                amount1Min: 1e18,
                recipient: address(this),
                deadline: block.timestamp + 1
            })
        );
    }

    function test_muni_mint() public {}
}
