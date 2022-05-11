import fs from 'fs'
import path from 'path'
import ethers from 'ethers'
import { fileURLToPath } from 'url';
import { wallet } from './common.js'

import IERC20 from "../out/IERC20.sol/IERC20.json"
import IUniswapV3FactoryArtifact from "@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json"
import IUniswapV3PoolArtifact from "@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json"
import INonfungiblePositionManagerArtifact from '@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json';
import DfxCadLogicV1Artifact from '../out/DfxCadLogicV1.sol/DfxCadLogicV1.json'
import { encodeSqrtRatioX96, FeeAmount, TickMath } from '@uniswap/v3-sdk';

const { formatUnits } = ethers.utils;

// Tokens
const DFXCAD = "0xFE32747d0251BA92bcb80b6D16C8257eCF25AB1C";
const CADC = "0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef";

// Uniswap contracts
const UNISWAP_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const UNISWAP_NFT_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";

// // Access controller
// const DFX_GOV_MULTISIG = '0x27E843260c71443b4CC8cB6bF226C3f77b9695AF'

// const DFX_CAD_NAME = "dfxCAD"
// const DFX_CAD_SYMBOL = "DFXCAD"

const main = async () => {
    const dfxCadToken = new ethers.Contract(DFXCAD, DfxCadLogicV1Artifact.abi, wallet);
    const cadcToken = new ethers.Contract(CADC, IERC20.abi, wallet);
    const nonfungiblePositionManager = new ethers.Contract(UNISWAP_NFT_MANAGER, INonfungiblePositionManagerArtifact.abi, wallet);
    const uniswapV3Factory = new ethers.Contract(UNISWAP_FACTORY, IUniswapV3FactoryArtifact.abi, wallet);

    // get total token supplies to ensure that addresses exist
    const dfxCadSupply = await dfxCadToken.balanceOf(wallet.address);
    const cadcSupply = await cadcToken.balanceOf(wallet.address);
    console.log(`Total supply--dfxCad: ${formatUnits(dfxCadSupply)} cadc: ${formatUnits(cadcSupply)}`);

    const dfxCadIsToken0 = dfxCadToken.address < cadcToken.address;
    console.log(`dfxCad is 0 token: ${dfxCadIsToken0}`);

    console.log("Creating UniswapV3 dfxCAD/CADC pool...");
    const feeAmount = FeeAmount.LOW;
    const tx0 = await uniswapV3Factory.createPool(dfxCadToken.address, cadcToken.address, feeAmount);
    await tx0.wait();

    const poolAddress = await uniswapV3Factory.getPool(dfxCadToken.address, cadcToken.address, feeAmount);
    console.log("Pool address:", poolAddress)

    console.log("Initializing UniswapV3 dfxCAD/CADC pool at 1 dfxCAD:1CADC...")
    const DfxCadCadcPool = new ethers.Contract(
        poolAddress, IUniswapV3PoolArtifact.abi, wallet,
    );

    // create sqrtPrice from 1 dfxCAD:1 CADC
    const sqrtRatioX96 = encodeSqrtRatioX96(1, 1);
    const tx1 = await DfxCadCadcPool.connect(wallet).initialize(sqrtRatioX96.toString());
    await tx1.wait();

    // Increase TWAP window like in Muni.t.sol tests
    await DfxCadCadcPool.increaseObservationCardinalityNext(5);

    // TickMath.getTickAtSqrtRatio()

    const tickSpacing = await DfxCadCadcPool.tickSpacing();
    console.log(tickSpacing);
    // const liquidity = 1_000;
    // const UniswapV3Factory = new ethers.Contract(
    //     "0x1F98431c8aD98523631AE4a59f267346ea31F984", IUniswapV3FactoryArtifact.abi, wallet
    // );

    // console.log(cadcToken.address.localeCompare(dfxCadToken.address))


    // const tx0 = await UniswapV3Factory.createPool(dfxCadToken.address, cadcToken.address, FeeAmount.LOW);
    // const tx0Receipt = await tx0.wait();
    // const poolAddress = tx0Receipt.logs[0].address;
    // console.log(poolAddress);

    // console.log("Fetching ticks from pool...");
    // const DfxCadCadcPool = new ethers.Contract(
    //     poolAddress, IUniswapV3PoolArtifact.abi, wallet,
    // );
    // const sqrtRatioX96 = encodeSqrtRatioX96(1, 1);
    // const tx1 = await DfxCadCadcPool.connect(wallet).initialize(sqrtRatioX96);
    // console.log(tx1);
    // const tickSpacing = await IUniswapV3Pool.tickSpacing();
    // console.log(tickSpacing)


    // const output = {
        // dfxCadCadcPool: dfxCadCadcPool.address,
        // dfxCadcProxy: dfxCadcProxy.address,
        // dfxCadcLogic: dfxCadcLogic.address,
        // dfxCadTwap: dfxCadTwap.address,
        // calldata: {
        //     dfxCadTwap: ethers.utils.defaultAbiCoder.encode(['address'], [
        //         TWAP_ROLE_ADMIN,
        //     ]),
        //     dfxCadcProxy: ethers.utils.defaultAbiCoder.encode(['address', 'address', 'bytes'], [
        //         dfxCadcLogic.address,
        //         DFX_CADC_PROXY_ADMIN,
        //         calldata
        //     ])
        // }
    // };

    // // Output to file
    // const __filename = fileURLToPath(import.meta.url);
    // const __dirname = path.dirname(__filename);
    // const outputPath = path.join(__dirname, new Date().getTime().toString() + `_uniswapv3_dfxcad-cadc.json`);
    // fs.writeFileSync(outputPath, JSON.stringify(output, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });