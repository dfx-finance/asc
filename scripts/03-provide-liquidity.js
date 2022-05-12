import fs from 'fs'
import path from 'path'
import ethers from 'ethers'
import { fileURLToPath } from 'url';
import { wallet, provider } from './common.js'

import IERC20 from "../out/IERC20.sol/IERC20.json";
import FiatTokenV2Artifact from "./abis/FiatTokenV2.json"

import DfxCadLogicV1Artifact from '../out/DfxCadLogicV1.sol/DfxCadLogicV1.json';
import MUNILogicV1Artifact from '../out/MUNILogicV1.sol/MUNILogicV1.json';
import IUniswapV2Router02 from '../out/IUniswapV2.sol/IUniswapV2Router02.json'
import IDfxCurve from '../out/IDfxCurve.sol/IDfxCurve.json';

const { formatUnits, parseUnits } = ethers.utils;


// Testing flag to automatically swap for collateral
const TESTING = true;

// Tokens
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const DFX = "0x888888435FDe8e7d4c54cAb67f206e4199454c60";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const CADC = "0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef";
const DFXCAD = "0xFE32747d0251BA92bcb80b6D16C8257eCF25AB1C";

// Minting addresses
const SUSHI_ROUTER = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F";
const DFX_CADC_USDC_CURVE = "0xa6C0CbCaebd93AD3C6c94412EC06aaA37870216d";

// MUNI
const MUNI_PROXY_ADDRESS = '0x9b4e383192a089C8177f5E1293FC037956Cfd884';


/*--- TESTING HELPERS ---*/
const testSwapForCollaterals = async () => {
    const sushiRouter = new ethers.Contract(SUSHI_ROUTER, IUniswapV2Router02.abi, wallet);
    const dfxUsdcCadcCurve = new ethers.Contract(DFX_CADC_USDC_CURVE, IDfxCurve.abi, wallet);
    const dfxToken = new ethers.Contract(DFX, IERC20.abi, wallet);
    const usdcToken = new ethers.Contract(USDC, FiatTokenV2Artifact, wallet);

    // Swap ETH->DFX
    let currentBlock = await provider.getBlock();
    let deadline = currentBlock.timestamp + 10 * 60;
    await sushiRouter.swapExactETHForTokens(
        0,
        [WETH, DFX],
        wallet.address,
        deadline,
        {value: parseUnits("1"), maxFeePerGas: 63972433966}
    );
    const dfx = await dfxToken.balanceOf(wallet.address);
    console.log("DFX balance:", formatUnits(dfx, 18));    

    // Swap ETH->USDC
    currentBlock = await provider.getBlock();
    deadline = currentBlock.timestamp + 10 * 60;
    await sushiRouter.swapExactETHForTokens(
        0,
        [WETH, USDC],
        wallet.address,
        deadline,
        {value: parseUnits("1"), maxFeePerGas: 63972433966}
    );
    const usdc = await usdcToken.balanceOf(wallet.address);
    console.log("USDC balance:", formatUnits(usdc, 6));

    // Swap USDC->CADC
    await usdcToken.approve(dfxUsdcCadcCurve.address, ethers.constants.MaxUint256);
    currentBlock = await provider.getBlock();
    deadline = currentBlock.timestamp + 10 * 60;    
    await dfxUsdcCadcCurve.originSwap(
        USDC,
        CADC,
        parseUnits("1000", 6),
        0,
        deadline
    );

    const cadcToken = new ethers.Contract(CADC, FiatTokenV2Artifact, wallet);
    const cadc = await cadcToken.balanceOf(wallet.address);
    console.log("CADC balance:", formatUnits(cadc));
}

const testMintDfxCad = async () => {
    const dfxToken = new ethers.Contract(DFX, IERC20.abi, wallet);
    const cadcToken = new ethers.Contract(CADC, FiatTokenV2Artifact, wallet);
    const dfxCadToken = new ethers.Contract(DFXCAD, DfxCadLogicV1Artifact.abi, wallet);

    await dfxToken.approve(dfxCadToken.address, ethers.constants.MaxUint256);
    await cadcToken.approve(dfxCadToken.address, ethers.constants.MaxUint256);
    await dfxCadToken.mint(parseUnits("1000"));

    const dfxCad = await dfxCadToken.balanceOf(wallet.address);
    console.log("dfxCAD balance:", formatUnits(dfxCad));
}

/*--- MAIN DEPLOYMENT ---*/
const main = async () => {
    // Setup
    if (TESTING) {
        await testSwapForCollaterals(wallet);
        await testMintDfxCad(wallet);
    }

    // Mint MUNI LP
    const userDfxCadToken = new ethers.Contract(DFXCAD, DfxCadLogicV1Artifact.abi, wallet);
    const userCadcToken = new ethers.Contract(CADC, FiatTokenV2Artifact, wallet);
    const muni = new ethers.Contract(MUNI_PROXY_ADDRESS, MUNILogicV1Artifact.abi, wallet);
    await userDfxCadToken.approve(muni.address, ethers.constants.MaxUint256);
    await userCadcToken.approve(muni.address, ethers.constants.MaxUint256);
    await muni.mint(parseUnits("1000"), wallet.address);
    const muniBalance = await muni.balanceOf(wallet.address);
    console.log("MUNI LP minted:", formatUnits(muniBalance));

    // Output to file
    const output = {
        muniLpMinted: formatUnits(muniBalance),
    };

    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const outputPath = path.join(__dirname, new Date().getTime().toString() + `_mint_muni_dfxcad-cadc.json`);
    fs.writeFileSync(outputPath, JSON.stringify(output, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });