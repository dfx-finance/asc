import { ethers } from "ethers";
import { wallet } from "./common.js";
import { encodeSqrtRatioX96, FeeAmount, TickMath } from "@uniswap/v3-sdk";

import IUniswapV3Artifact from "@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json";
import MUNILogicV1Artifact from "../out/MUNILogicV1.sol/MUNILogicV1.json";

// UniV3 dfxCAD/CADC Pool
const UNISWAP_V3_POOL = "0xFca463b342891CdfDc77180A694582BF1fc6C954";

// MUNI Logic Contract (base, non-proxied)
const MUNI_LOGIC = "0xA2bF8A967a54339D745160b08fe2e9813bD62471";

// Access controller
const DFX_GOV_MULTISIG = "0x27E843260c71443b4CC8cB6bF226C3f77b9695AF";

const main = async () => {
    const muniLogicV1 = new ethers.Contract(MUNI_LOGIC, MUNILogicV1Artifact.abi, wallet);
    const dfxCadCadcPool = new ethers.Contract(UNISWAP_V3_POOL, IUniswapV3Artifact.abi, wallet);
 
    const tickSpacing = await dfxCadCadcPool.tickSpacing();
    const lowerSqrtPriceX96 = encodeSqrtRatioX96(980, 1000);
    const upperSqrtPriceX96 = encodeSqrtRatioX96(1020, 1000);
    const lowerTickAmount = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);
    const upperTickAmount = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);
    const lowerTick = lowerTickAmount - (lowerTickAmount % tickSpacing);
    const upperTick = upperTickAmount - (upperTickAmount % tickSpacing);

    const tx = await muniLogicV1.initialize(
        DFX_GOV_MULTISIG, // owner
        UNISWAP_V3_POOL,
        FeeAmount.LOWEST,
        lowerTick,
        upperTick,        
    )
    tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });