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

import "../../oracles/DfxEurTWAP.sol";

contract DfxEurTWAPTest is DSTest, stdCheats {
    DfxEurTWAP twap;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(Mainnet.SUSHI_ROUTER);
    IDfxCurve dfxUsdEurA =
        IDfxCurve(0x1a4Ffe0DCbDB4d551cfcA61A5626aFD190731347);

    IERC20 dfx = IERC20(Mainnet.DFX);
    IERC20 eurs = IERC20(Mainnet.EURS);
    IERC20 usdc = IERC20(Mainnet.USDC);

    function setUp() public {
        twap = new DfxEurTWAP(address(this));
        dfx.approve(address(sushiRouter), type(uint256).max);
        usdc.approve(address(dfxUsdEurA), type(uint256).max);
    }

    function test_dfxeurtwap() public {
        uint256 eurPerDfx = twap.read();
        assertGt(eurPerDfx, 0);

        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();
        cheats.warp(block.timestamp + twap.period() + 1);
        twap.update();

        eurPerDfx = twap.read();
        assertGt(eurPerDfx, 0);

        // Now do a real world comparison
        // 1 DFX -> WETH -> USDC @ sushi
        // USDC -> EURS @ dfx
        uint256 _before = eurs.balanceOf(address(this));
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
        dfxUsdEurA.originSwap(
            address(usdc),
            address(eurs),
            usdc.balanceOf(address(this)),
            0,
            block.timestamp + 1
        );

        // 1e16 Adjusting for eurs decimal places
        uint256 spotEurPerDfx = (eurs.balanceOf(address(this)) - _before) * 1e16;

        uint256 deltaPercentage = eurPerDfx > spotEurPerDfx
            ? (spotEurPerDfx * 1e18) / eurPerDfx
            : (eurPerDfx * 1e18) / spotEurPerDfx;

        // Correct up to 96% (less because EURS is 2 decimals) 
        assertGt(deltaPercentage, 96e16);
    }
}
