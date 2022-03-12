// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../lib/Address.sol";

import "../../interfaces/IChainLinkOracle.sol";
import "../../oracles/UniswapV3Oracle.sol";

contract UniswapV3OracleTest is DSTest {
    UniswapV3Oracle univ3Oracle;

    function setUp() public {
        univ3Oracle = new UniswapV3Oracle();
    }

    function test_univ3Oracle_weth_dai_consult() public {
        // 1 WETH = X USDC
        uint256 wethPrice = univ3Oracle.consult(
            3000,
            Mainnet.WETH,
            Mainnet.USDC
        );

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
