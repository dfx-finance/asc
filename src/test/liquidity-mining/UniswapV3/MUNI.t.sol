// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../../lib/Address.sol";
import "../../lib/CheatCodes.sol";
import "../../lib/MockToken.sol";
import "../../lib/MockUser.sol";

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

    MockUser user;
    MockToken token0;
    MockToken token1;

    IUniswapV3Pool pool;

    INonfungiblePositionManager univ3PosManager =
        INonfungiblePositionManager(Mainnet.UNIV3_POS_MANAGER);

    uint24 public constant fee = 3000;
    int24 tickSpacing;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        user = new MockUser();
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
            .fraction(1, 2)
            .sqrt()
            .mul(2**96)
            .decode144();
        uint160 upperSqrtPriceX96 = FixedPoint
            .fraction(2, 1)
            .sqrt()
            .mul(2**96)
            .decode144();

        int24 lowerTick = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);
        lowerTick = lowerTick - (lowerTick % tickSpacing);

        int24 upperTick = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);
        upperTick = upperTick - (upperTick % tickSpacing) + tickSpacing;

        token0.mint(address(this), 1_000_000_000e18);
        token1.mint(address(this), 1_000_000_000e18);

        token0.approve(address(univ3PosManager), 1_000_000_000e18);
        token1.approve(address(univ3PosManager), 1_000_000_000e18);

        univ3PosManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: fee,
                tickLower: lowerTick,
                tickUpper: upperTick,
                amount0Desired: 1_000_000_000e18,
                amount1Desired: 1_000_000_000e18,
                amount0Min: 0e18,
                amount1Min: 0e18,
                recipient: address(this),
                deadline: block.timestamp + 1
            })
        );
    }

    function test_muni_mint(uint128 tokenAmount)
        public
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 lpAmount
        )
    {
        cheats.assume(tokenAmount > 1e6);
        cheats.assume(tokenAmount < 1_000_000_000_000e18);

        (amount0, amount1, lpAmount) = muni.getMintAmounts(
            tokenAmount,
            tokenAmount
        );

        assertGt(amount0, 0);
        assertGt(amount1, 0);

        token0.mint(address(this), amount0);
        token0.approve(address(muni), amount0);

        token1.mint(address(this), amount1);
        token1.approve(address(muni), amount1);

        assertEq(muni.balanceOf(address(this)), 0);
        muni.mint(lpAmount, address(this));
        assertEq(muni.balanceOf(address(this)), lpAmount);

        // Should get back ~same amount if we burn
        (uint256 retAmount0, uint256 retAmount1) = muni.getBurnAmounts(
            lpAmount
        );
        uint256 delta0 = (retAmount0 * 1e18) / amount0;
        uint256 delta1 = (retAmount1 * 1e18) / amount1;

        assertTrue(delta0 > 98e16 && delta0 <= 1e18);
        assertTrue(delta1 > 98e16 && delta1 <= 1e18);
    }

    function test_muni_burn(uint128 tokenAmount) public {
        test_muni_mint(tokenAmount);

        assertEq(token0.balanceOf(address(this)), 0);
        assertEq(token1.balanceOf(address(this)), 0);

        uint256 lpAmount = muni.balanceOf(address(this));
        (uint256 amount0, uint256 amount1) = muni.getBurnAmounts(lpAmount);

        assertGt(lpAmount, 0);
        assertGt(amount0, 0);
        assertGt(amount1, 0);

        muni.burn(lpAmount, address(this));
        assertEq(token0.balanceOf(address(this)), amount0);
        assertEq(token1.balanceOf(address(this)), amount1);
    }

    function test_muni_rebalance(uint128 tokenAmount) public {
        test_pool_nftpositionmanager();
        (uint256 aAmount0, uint256 aAmount1, uint256 aLpAmount) = test_muni_mint(tokenAmount);

        int24 lowerTick = muni.lowerTick();
        lowerTick = lowerTick - tickSpacing;

        int24 upperTick = muni.upperTick();
        upperTick = upperTick + tickSpacing;

        uint160 swapThresholdPriceX96 = FixedPoint
            .fraction(1, 2)
            .sqrt()
            .mul(2**96)
            .decode144();

        // Should have less liquidity in ticks
        uint256 liquidityBefore = pool.liquidity();
        muni.executiveRebalance(
            lowerTick,
            upperTick,
            swapThresholdPriceX96,
            0,
            true
        );
        uint256 liquidityAfter = pool.liquidity();

        assertGt(liquidityBefore, 0);
        assertGt(liquidityAfter, 0);
        assertLt(liquidityAfter, liquidityBefore);

        // Make sure we can still remove roughly the same tokenAmount
        uint256 lpAmount = muni.balanceOf(address(this));
        (uint256 amount0, uint256 amount1) = muni.getBurnAmounts(lpAmount);

        // LP amount shouldn't change
        assertEq(lpAmount, aLpAmount);

        // amount0 and amount1 should be roughly similar
        uint256 delta0 = amount0 * 1e18 / aAmount0;
        uint256 delta1 = amount1 * 1e18 / aAmount1;

        assertTrue(delta0 > 99e16 && delta0 <= 1e18);
        assertTrue(delta1 > 99e16 && delta1 <= 1e18);
    }

    function testFail_muni_user_renounceOwnership() public {
        user.call(
            address(muni),
            abi.encodeWithSelector(
                muni.renounceOwnership.selector
            )
        );
    }

    function testFail_muni_owner_renounceOwnership() public {
        cheats.prank(address(this));
        muni.renounceOwnership();
    }
}
