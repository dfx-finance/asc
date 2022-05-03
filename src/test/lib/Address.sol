// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library Mainnet {
    // Tokens
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DFX = 0x888888435FDe8e7d4c54cAb67f206e4199454c60;
    address public constant CADC = 0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef;

    address public constant DFX_CAD = 0xFE32747d0251BA92bcb80b6D16C8257eCF25AB1C;
    address public constant DFX_CAD_GOV = 0x27E843260c71443b4CC8cB6bF226C3f77b9695AF;
    address public constant DFX_CAD_ACCESS_CONTROLLER = 0xc9F05FA7049b32712c5D6675eBDEd167150475c4;
    address public constant DFX_CAD_TREASURY = 0x26f539A0fE189A7f228D7982BF10Bc294FA9070c;

    // Oracles

    // 8-decimals
    address public constant CHAINLINK_WETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // Managed Uniswap
    address public constant DFX_CAD_CADC_MUNI = 0x0000000000000000000000000000000000000000;

    // Addresses
    address public constant UNIV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address public constant UNIV3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant UNIV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant UNIV3_POS_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    address public constant SUSHI_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address public constant SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
}
