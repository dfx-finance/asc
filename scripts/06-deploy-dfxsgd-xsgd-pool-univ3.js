import fs from "fs";
import path from "path";
import ethers from "ethers";
import { fileURLToPath } from "url";
import { deployContract, wallet } from "./common.js";

import FiatTokenV2Artifact from "./abis/FiatTokenV2.json";
import IUniswapV3FactoryArtifact from "@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json";
import IUniswapV3PoolArtifact from "@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json";

import DfxSgdLogicArtifact from "../out/DfxSgdLogic.sol/DfxSgdLogic.json";
import MUNILogicV1Artifact from "../out/MUNILogicV1.sol/MUNILogicV1.json";
import ASCUpgradableProxyArtifact from "../out/ASCUpgradableProxy.sol/ASCUpgradableProxy.json";

import { encodeSqrtRatioX96, FeeAmount, TickMath } from "@uniswap/v3-sdk";

const { formatUnits } = ethers.utils;

// Tokens
const XSGD = "0x70e8dE73cE538DA2bEEd35d14187F6959a8ecA96";
const XSGD_DECIMALS = 6;
const DFXSGD = "0x52dDdA10eb0abdb34528329C4aF16d218AB95bD1";

// Uniswap contracts
const UNISWAP_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";

// Access controller
const DFX_GOV_MULTISIG = "0x27E843260c71443b4CC8cB6bF226C3f77b9695AF";

const main = async () => {
  const dfxSgdToken = new ethers.Contract(
    DFXSGD,
    DfxSgdLogicArtifact.abi,
    wallet
  );
  const xsgdToken = new ethers.Contract(XSGD, FiatTokenV2Artifact, wallet);
  const uniswapV3Factory = new ethers.Contract(
    UNISWAP_FACTORY,
    IUniswapV3FactoryArtifact.abi,
    wallet
  );
  const MUNILogicFactory = new ethers.ContractFactory(
    MUNILogicV1Artifact.abi,
    MUNILogicV1Artifact.bytecode.object,
    wallet
  );
  const UpgradableProxyFactory = new ethers.ContractFactory(
    ASCUpgradableProxyArtifact.abi,
    ASCUpgradableProxyArtifact.bytecode.object,
    wallet
  );

  // Check token addresses both exist
  const dfxSgdBalance = await dfxSgdToken.balanceOf(wallet.address);
  const xsgdBalance = await xsgdToken.balanceOf(wallet.address);
  console.log(
    `Total balance--dfxSgd: ${formatUnits(dfxSgdBalance)} XSGD: ${formatUnits(
      xsgdBalance, XSGD_DECIMALS
    )}`
  );

  // Create the new Uniswap pool
  console.log("Creating UniswapV3 dfxSGD/XSGD pool...");
  const feeAmount = FeeAmount.LOWEST;
  const tx_createPool = await uniswapV3Factory.createPool(
    dfxSgdToken.address,
    xsgdToken.address,
    feeAmount
  );
  await tx_createPool.wait();

  // Fetch pool's address
  const poolAddress = await uniswapV3Factory.getPool(
    dfxSgdToken.address,
    xsgdToken.address,
    feeAmount
  );
  console.log("Pool address:", poolAddress);

  // Instantiate ethers ABI on pool address
  console.log("Initializing UniswapV3 dfxSGD/XSGD pool at 1 dfxSGD:1XSGD...");
  const DfxSgdXsgdPool = new ethers.Contract(
    poolAddress,
    IUniswapV3PoolArtifact.abi,
    wallet
  );

  // Read token order from pool and set 1 unit in expected number of decimals
  const token0Address = await DfxSgdXsgdPool.token0();
  const token0Decimals1Unit = token0Address === DFXSGD ? 1e18 : 1 * 10 ** XSGD_DECIMALS;
  const token1Decimals1Unit = token0Address === DFXSGD ? 1 * 10 ** XSGD_DECIMALS : 1e18;

  // Create sqrtPrice from 1 dfxSGD:1 XSGD and initialize pool
  const sqrtRatioX96 = encodeSqrtRatioX96(token0Decimals1Unit, token1Decimals1Unit);
  console.log("Initializing sqrtRatioX96...");
  await DfxSgdXsgdPool.connect(wallet).initialize(sqrtRatioX96.toString(), {
    gasLimit: 500_000,
  });

  // Increase TWAP window like in Muni.t.sol tests
  console.log("increaseObservationCardinalityNext...");
  const tx_increaseObservationCardinalityNext =
    await DfxSgdXsgdPool.increaseObservationCardinalityNext(5, {
      gasLimit: 500_000,
    });
  await tx_increaseObservationCardinalityNext.wait();

  const tickSpacing = await DfxSgdXsgdPool.tickSpacing();
  const lowerSqrtPriceX96 = encodeSqrtRatioX96(980, 1000);
  const upperSqrtPriceX96 = encodeSqrtRatioX96(1020, 1000);
  const lowerTickAmount = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);
  const upperTickAmount = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);
  const lowerTick = lowerTickAmount - (lowerTickAmount % tickSpacing);
  const upperTick = upperTickAmount - (upperTickAmount % tickSpacing);

  // Deploy MUNI contract
  const muniLogicV1 = await deployContract({
    name: "MUNILogicV1",
    deployer: wallet,
    factory: MUNILogicFactory,
    args: [],
    opts: {
      gasLimit: 5_000_000,
    },
  });

  // Deploy ASCUpgradableProxy with the encoded args and initialize MUNI pool
  const calldata = MUNILogicFactory.interface.encodeFunctionData("initialize", [
    DFX_GOV_MULTISIG, // owner
    poolAddress,
    FeeAmount.LOWEST,
    lowerTick,
    upperTick,
  ]);
  const muniProxy = await deployContract({
    name: "DFX MUNI dfxSGD/XSGD",
    deployer: wallet,
    factory: UpgradableProxyFactory,
    args: [muniLogicV1.address, wallet.address, calldata],
    opts: {
      gasLimit: 5_000_000,
    },
  });

  // Output to file
  const output = {
    muniProxy: muniProxy.address,
    calldata: {
      muni: ethers.utils.defaultAbiCoder.encode(
        ["address", "address", "uint", "int", "int"],
        [wallet.address, poolAddress, FeeAmount.LOWEST, lowerTick, upperTick]
      ),
    },
  };

  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const outputPath = path.join(
    __dirname,
    new Date().getTime().toString() + `_uniswapv3_dfxsgd-xsgd.json`
  );
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 4));
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
