import { ethers } from "ethers";
import { wallet } from "./common.js";
import { encodeSqrtRatioX96, FeeAmount, TickMath } from "@uniswap/v3-sdk";

import IUniswapV3Artifact from "@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json";
import MUNILogicV1Artifact from "../out/MUNILogicV1.sol/MUNILogicV1.json";

// UniV3 dfxSGD/XSGD Pool
const UNISWAP_V3_POOL = "0xffae7370844307306672Ced610936C149203dfF2";

// MUNI Logic Contract (base, non-proxied)
const MUNI_LOGIC = "0xd39A7DE0Fe4869CCB8D03D64b245a04e16342044";

// Access controller
const DFX_GOV_MULTISIG = "0x27E843260c71443b4CC8cB6bF226C3f77b9695AF";

const main = async () => {
    const muniLogicV1 = new ethers.Contract(MUNI_LOGIC, MUNILogicV1Artifact.abi, wallet);
    const dfxSgdXsgdPool = new ethers.Contract(UNISWAP_V3_POOL, IUniswapV3Artifact.abi, wallet);
 
    const tickSpacing = await dfxSgdXsgdPool.tickSpacing();
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