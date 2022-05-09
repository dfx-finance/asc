// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import {stdCheats} from "@forge-std/stdlib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/IChainLinkOracle.sol";
import "../../interfaces/IUniswapV2.sol";
import "../../interfaces/IDfxCurve.sol";

import "../../oracles/DfxSgdTWAP.sol";

contract DfxSgdTWAPTest is DSTest, stdCheats {
    DfxSgdTWAP twap;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(Mainnet.SUSHI_ROUTER);
    IDfxCurve dfxUsdSgdA =
        IDfxCurve(0x2baB29a12a9527a179Da88F422cDaaA223A90bD5);

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 xsgd = IERC20(Mainnet.XSGD);
    IERC20 usdc = IERC20(Mainnet.USDC);

    function setUp() public {
        twap = new DfxSgdTWAP(address(this));
        dfx.approve(address(sushiRouter), type(uint256).max);
        usdc.approve(address(dfxUsdSgdA), type(uint256).max);
    }

    function test_dfxsgdtwap() public {
        uint256 sgdPerDfx = twap.read();
        assertGt(sgdPerDfx, 0);

        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();
        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();

        sgdPerDfx = twap.read();
        assertGt(sgdPerDfx, 0);

        // Now do a real world comparison
        // 1 DFX -> WETH -> USDC @ sushi
        // USDC -> XSGD @ dfx
        uint256 _before = xsgd.balanceOf(address(this));
        address[] memory path = new address[](3);
        path[0] = Mainnet.DFX;
        path[1] = Mainnet.WETH;
        path[2] = Mainnet.USDC;

        tip(address(dfx), address(this), 1e18);
        sushiRouter.swapExactTokensForTokens(
            1e18,
            0,
            path,
            address(this),
            block.timestamp
        );
        dfxUsdSgdA.originSwap(
            address(usdc),
            address(xsgd),
            usdc.balanceOf(address(this)),
            0,
            block.timestamp + 1
        );

        // 1e12 Adjusting for xsgd decimal places
        uint256 spotSgdPerDfx = (xsgd.balanceOf(address(this)) - _before) * 1e12;

        uint256 deltaPercentage = sgdPerDfx > spotSgdPerDfx
            ? (spotSgdPerDfx * 1e18) / sgdPerDfx
            : (sgdPerDfx * 1e18) / spotSgdPerDfx;

        // Correct up to 98% 
        assertGt(deltaPercentage, 98e16);
    }
}
