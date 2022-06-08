// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../../interfaces/IUniswapV3.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMUNI is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    function mint(uint256 mintAmount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityMinted);
    function burn(uint256 burnAmount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function executiveRebalance(int24 newLowerTick, int24 newUpperTick, uint160 swapThresholdPrice, uint256 swapAmountBPS, bool zeroForOne) external;
    function rebalance(uint160 swapThresholdPrice, uint256 swapAmountBPS, bool zeroForOne, uint256 feeAmount, address paymentToken) external;
    function withdrawManagerBalance(uint256 feeAmount, address feeToken) external;

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external override;
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override;

    function getPositionID() external view returns (bytes32 positionID); 
    function getUnderlyingBalances() external view returns (uint256 amount0Current, uint256 amount1Current);
    function getMintAmounts(uint256 amount0Max, uint256 amount1Max) external view returns (uint256 amount0, uint256 amount1, uint256 mintAmount);
    function getBurnAmounts(uint256 lpAmount) external view returns (uint256 amount0, uint256 amount1);
    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96) external view returns (uint256 amount0Current, uint256 amount1Current);

    event Minted(
        address receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In,
        uint128 liquidityMinted
    );

    event Burned(
        address receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out,
        uint128 liquidityBurned
    );

    event Rebalance(
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidityBefore,
        uint128 liquidityAfter
    );

    event FeesEarned(uint256 feesEarned0, uint256 feesEarned1);

    function managerFeeBPS() external view returns (uint16);
    function managerBalance0() external view returns (uint256);
    function managerBalance1() external view returns (uint256);
    function lowerTick() external view returns (int24);
    function upperTick() external view returns (int24);

    function pool() external view returns (IUniswapV3Pool);
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
}
