// SPDX-License-Identifier: MIT
// https://etherscan.io/address/0x8eed20f31e7d434648ff51114446b3cffd1ff9f1#code

pragma solidity ^0.8.10;

import "../libraries/UniswapV3.sol";

contract UniswapV3Oracle {
    address internal constant UNIV3_FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    uint32 internal constant TWAP_PERIOD = 6 hours;

    function consult(
        uint24 feeTier,
        address baseToken,
        address quoteToken
    ) public view returns (uint256) {
        address pool = IUniswapV3Factory(UNIV3_FACTORY).getPool(
            baseToken,
            quoteToken,
            feeTier
        );

        (int24 arithmeticAverageTick, ) = UniswapV3OracleLibrary.consult(
            pool,
            TWAP_PERIOD
        );

        uint256 baseUnit = 10**uint128(IERC20Metadata(baseToken).decimals());

        uint256 quote = UniswapV3OracleLibrary.getQuoteAtTick(
            arithmeticAverageTick,
            uint128(baseUnit),
            baseToken,
            quoteToken
        );

        return quote;
    }
}
