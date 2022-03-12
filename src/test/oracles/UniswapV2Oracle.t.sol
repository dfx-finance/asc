// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import "../../interfaces/IChainLinkOracle.sol";
import "../../oracles/UniswapV2Oracle.sol";

contract UniswapV2OracleTest is DSTest {
    UniswapV2Oracle univ2Oracle;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        univ2Oracle = new UniswapV2Oracle(
            Mainnet.UNIV2_FACTORY,
            Mainnet.WETH,
            Mainnet.USDC,
            1 hours
        );
    }

    function test_univ2Oracle_weth_dai_consult() public {
        address[] memory path = new address[](2);
        path[0] = Mainnet.WETH;
        path[1] = Mainnet.USDC;

        cheats.warp(block.timestamp + 6 hours + 10 minutes);
        IUniswapV2Router02(Mainnet.UNIV2_ROUTER).swapExactETHForTokens{
            value: 1e18
        }(0, path, address(this), block.timestamp + 1);
        univ2Oracle.update();
        uint256 wethPrice = univ2Oracle.consult(Mainnet.WETH, 1e18);

        // 8 decimals, convert to 6
        (, int256 _wethPriceChainLink, , , ) = IChainLinkOracle(
            Mainnet.CHAINLINK_WETH_USD
        ).latestRoundData();
        uint256 wethPriceCL = uint256(_wethPriceChainLink / 1e2);

        // Delta within 2%
        uint256 delta = wethPriceCL > wethPrice
            ? (wethPrice * 1e6) / wethPriceCL
            : (wethPriceCL * 1e6) / wethPrice;

        // 990000 = 99% in 1e6 land
        assertGt(delta, 990000);
    }
}
