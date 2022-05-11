import fs from 'fs'
import path from 'path'
import ethers from 'ethers'
import { fileURLToPath } from 'url';
import { deployContract, wallet } from './common.js'

import IERC20 from "../out/IERC20.sol/IERC20.json"
import IUniswapV3FactoryArtifact from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json';
import IUniswapV3PoolArtifact from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json';
import INonfungiblePositionManagerArtifact from '@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json';
import DfxCadLogicV1Artifact from '../out/DfxCadLogicV1.sol/DfxCadLogicV1.json';
import MUNILogicV1Artifact from '../out/MUNILogicV1.sol/MUNILogicV1.json';
import ASCUpgradableProxyArtifact from '../out/ASCUpgradableProxy.sol/ASCUpgradableProxy.json';
import { encodeSqrtRatioX96, FeeAmount, TickMath } from '@uniswap/v3-sdk';

const { formatUnits } = ethers.utils;

// Tokens
const DFXCAD = "0xFE32747d0251BA92bcb80b6D16C8257eCF25AB1C";
const CADC = "0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef";

// Uniswap contracts
const UNISWAP_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const UNISWAP_NFT_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";

// Access controller
const DFX_GOV_MULTISIG = '0x27E843260c71443b4CC8cB6bF226C3f77b9695AF'


const main = async () => {
    const dfxCadToken = new ethers.Contract(DFXCAD, DfxCadLogicV1Artifact.abi, wallet);
    const cadcToken = new ethers.Contract(CADC, IERC20.abi, wallet);
    const nonfungiblePositionManager = new ethers.Contract(UNISWAP_NFT_MANAGER, INonfungiblePositionManagerArtifact.abi, wallet);
    const uniswapV3Factory = new ethers.Contract(UNISWAP_FACTORY, IUniswapV3FactoryArtifact.abi, wallet);

    // Check token addresses both exist
    const dfxCadSupply = await dfxCadToken.balanceOf(wallet.address);
    const cadcSupply = await cadcToken.balanceOf(wallet.address);
    console.log(`Total supply--dfxCad: ${formatUnits(dfxCadSupply)} cadc: ${formatUnits(cadcSupply)}`);

    // Create the new Uniswap pool
    console.log("Creating UniswapV3 dfxCAD/CADC pool...");
    const feeAmount = FeeAmount.LOWEST;
    const tx0 = await uniswapV3Factory.createPool(dfxCadToken.address, cadcToken.address, feeAmount);
    await tx0.wait();

    // Fetch pool's address
    const poolAddress = await uniswapV3Factory.getPool(dfxCadToken.address, cadcToken.address, feeAmount);
    console.log("Pool address:", poolAddress)

    // Instantiate ethers ABI on pool address
    console.log("Initializing UniswapV3 dfxCAD/CADC pool at 1 dfxCAD:1CADC...")
    const DfxCadCadcPool = new ethers.Contract(
        poolAddress, IUniswapV3PoolArtifact.abi, wallet,
    );

    // Create sqrtPrice from 1 dfxCAD:1 CADC and initialize pool
    const sqrtRatioX96 = encodeSqrtRatioX96(1, 1);
    const tx1 = await DfxCadCadcPool.connect(wallet).initialize(sqrtRatioX96.toString());
    await tx1.wait();

    // Increase TWAP window like in Muni.t.sol tests
    await DfxCadCadcPool.increaseObservationCardinalityNext(5);

    const tickSpacing = await DfxCadCadcPool.tickSpacing();
    const lowerSqrtPriceX96 = encodeSqrtRatioX96(1000, 1004);
    const upperSqrtPriceX96 = encodeSqrtRatioX96(1004, 1000);
    const lowerTickAmount = TickMath.getTickAtSqrtRatio(lowerSqrtPriceX96);
    const upperTickAmount = TickMath.getTickAtSqrtRatio(upperSqrtPriceX96);
    const lowerTick = lowerTickAmount - (lowerTickAmount % tickSpacing);
    const upperTick = upperTickAmount - (upperTickAmount % tickSpacing);

    // Deploy MUNI contract
    const MUNILogicFactory = new ethers.ContractFactory(
        MUNILogicV1Artifact.abi, MUNILogicV1Artifact.bytecode.object, wallet
    )
    const UpgradableProxyFactory = new ethers.ContractFactory(
        ASCUpgradableProxyArtifact.abi, ASCUpgradableProxyArtifact.bytecode.object, wallet
    )

    const muniLogicV1 = await deployContract({
        name: 'MUNILogicV1',
        deployer: wallet,
        factory: MUNILogicFactory,
        args: [],
        opts: {
            maxFeePerGas: 54796832180,
        }
    });

    // Deploy ASCUpgradableProxy with the encoded args and initialize MUNI pool
    const calldata = MUNILogicFactory.interface.encodeFunctionData("initialize", [
        DFX_GOV_MULTISIG,  // owner
        poolAddress,
        FeeAmount.LOWEST,
        lowerTick,
        upperTick,
    ]);
    const MUNIProxy = await deployContract({
        name: 'MUNI',
        deployer: wallet,
        factory: UpgradableProxyFactory,
        args: [
            muniLogicV1.address,
            DFX_GOV_MULTISIG,
            calldata
        ],
        opts: {
            // gasLimit: 1667809
        }
    });

    console.log(MUNIProxy.address)

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