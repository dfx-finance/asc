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

import "../../oracles/DfxCadTWAP.sol";

contract DfxCadTWAPTest is DSTest, stdCheats {
    DfxCadTWAP twap;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(Mainnet.SUSHI_ROUTER);
    IDfxCurve dfxUsdcCadcA =
        IDfxCurve(0xa6C0CbCaebd93AD3C6c94412EC06aaA37870216d);

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 cadc = IERC20(Mainnet.CADC);
    IERC20 usdc = IERC20(Mainnet.USDC);

    function setUp() public {
        twap = new DfxCadTWAP(address(this));
        dfx.approve(address(sushiRouter), type(uint256).max);
        usdc.approve(address(dfxUsdcCadcA), type(uint256).max);
    }

    function test_dfxcadtwap() public {
        uint256 cadcPerDfx = twap.read();
        assertEq(cadcPerDfx, 0);

        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();
        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();

        cadcPerDfx = twap.read();
        assertGt(cadcPerDfx, 0);

        // Now do a real world comparison
        // 1 DFX -> WETH -> USDC @ sushi
        // USDC -> CADC @ dfx
        uint256 _before = cadc.balanceOf(address(this));
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
        dfxUsdcCadcA.originSwap(
            address(usdc),
            address(cadc),
            usdc.balanceOf(address(this)),
            0,
            block.timestamp + 1
        );

        uint256 spotCadcPerDfx = cadc.balanceOf(address(this)) - _before;

        uint256 deltaPercentage = cadcPerDfx > spotCadcPerDfx
            ? (spotCadcPerDfx * 1e18) / cadcPerDfx
            : (cadcPerDfx * 1e18) / spotCadcPerDfx;

        // Correct up to 98% 
        assertGt(deltaPercentage, 98e16);
    }
}
