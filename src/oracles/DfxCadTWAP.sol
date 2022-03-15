// SPDX-License-Identifier: MIT
// https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol

pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import "../interfaces/IDfxOracle.sol";
import "../interfaces/IChainLinkOracle.sol";

import "./UniswapV2Oracle.sol";

contract DfxCadTWAP is UniswapV2Oracle, IDfxOracle {
    address internal constant SUSHI_FACTORY =
        0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DFX = 0x888888435FDe8e7d4c54cAb67f206e4199454c60;

    IChainLinkOracle ETH_USD_ORACLE =
        IChainLinkOracle(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IChainLinkOracle CAD_USD_ORACLE =
        IChainLinkOracle(0xa34317DB73e77d453b1B8d04550c44D10e981C8e);

    constructor() UniswapV2Oracle(SUSHI_FACTORY, DFX, WETH, 6 hours) {}

    function update() public override {
        require(msg.sender == tx.origin, "no-bots");
        super.update();
    }

    /// @notice Returns price of DFX in CAD, e.g. 1 DFX = X CAD
    ///         Will assume 1 CADC = 1 CAD in this case
    function read() public view override returns (uint256) {
        // 18 dec
        uint256 wethPerDfx18 = consult(DFX, 1e18);

        // in256, 8 dec -> uint256 18 dec
        (, int256 usdPerEth8, , , ) = ETH_USD_ORACLE.latestRoundData();
        (, int256 usdPerCad8, , , ) = CAD_USD_ORACLE.latestRoundData();
        uint256 usdPerEth18 = uint256(usdPerEth8) * 1e10;
        uint256 usdPerCad18= uint256(usdPerCad8) * 1e10;

        // (eth/dfx) * (usd/eth) = usd/dfx
        uint256 usdPerDfx = wethPerDfx18 * usdPerEth18 / 1e18;

        // (usd/dfx) / (usd/cad) = cad/dfx
        uint256 cadPerDfx = usdPerDfx * 1e18 / usdPerCad18;

        return cadPerDfx;
    }
}
