import fs from 'fs'
import path from 'path'
import ethers from 'ethers'
import { fileURLToPath } from 'url';
import { parseUnits } from '@ethersproject/units'
import { wallet, deployContract } from './common.js'

import DfxCadTwapArtifact from '../out/DfxCadTWAP.sol/DfxCadTWAP.json'
import DfxCadcLogicArtifact from '../out/DfxCadcLogic.sol/DfxCadcLogic.json'
import ASCUpgradableProxyArtifact from '../out/ASCUpgradableProxy.sol/ASCUpgradableProxy.json'

// Manages access control in twap
const TWAP_ROLE_ADMIN = wallet.address

// Proxy admin is only used for upgrading proxy logic
const DFX_CADC_PROXY_ADMIN = wallet.address

const DFX_CADC_NAME = "dfxCADC"
const DFX_CADC_SYMBOL = "DFXCADC"
const DFX_CADC_ROLE_ADMIN = wallet.address // DFX_CADC_ADMIN is used to manage (all) roles
const DFX_CADC_FEE_RECIPIENT = wallet.address
const DFX_CADC_MINT_BURN_FEE = parseUnits('0.005') // 0.5%
const CADC_RATIO = parseUnits('0.95') // 95%
const DFX_RATIO = parseUnits('0.05') // 5%
const POKE_RATIO_DELTA = parseUnits('0.005') // 0.5%

const main = async () => {
    const TwapFactory = new ethers.ContractFactory(
        DfxCadTwapArtifact.abi, DfxCadTwapArtifact.bytecode.object, wallet
    )
    const LogicFactory = new ethers.ContractFactory(
        DfxCadcLogicArtifact.abi, DfxCadcLogicArtifact.bytecode.object, wallet
    )
    const UpgradableProxyFactory = new ethers.ContractFactory(
        ASCUpgradableProxyArtifact.abi, ASCUpgradableProxyArtifact.bytecode.object, wallet
    )

    // // 1. Deploy TWAP
    const dfxCadTwap = await deployContract({
        name: 'DfxCadTWAP',
        deployer: wallet,
        factory: TwapFactory,
        args: [TWAP_ROLE_ADMIN]
    })

    // 2. Deploy logic
    const dfxCadcLogic = await deployContract({
        name: 'DfxCadcLogic',
        deployer: wallet,
        factory: LogicFactory,
        args: []
    })

    // 3. Deploy ASCUpgradableProxy with the encoded args
    const calldata = LogicFactory.interface.encodeFunctionData("initialize", [
        DFX_CADC_NAME, DFX_CADC_SYMBOL, DFX_CADC_ROLE_ADMIN, DFX_CADC_FEE_RECIPIENT, DFX_CADC_MINT_BURN_FEE, dfxCadTwap.address, CADC_RATIO, DFX_RATIO, POKE_RATIO_DELTA
    ])
    const dfxCadcProxy = await deployContract({
        name: 'DfxCadc',
        deployer: wallet,
        factory: UpgradableProxyFactory,
        args: [
            dfxCadcLogic.address,
            DFX_CADC_PROXY_ADMIN,
            calldata
        ]
    })

    const output = {
        dfxCadcProxy: dfxCadcProxy.address,
        dfxCadcLogic: dfxCadcLogic.address,
        dfxCadTwap: dfxCadTwap.address,
        calldata: {
            dfxCadTwap: ethers.utils.defaultAbiCoder.encode(['address'], [
                TWAP_ROLE_ADMIN,
            ]),
            dfxCadcProxy: ethers.utils.defaultAbiCoder.encode(['address', 'address', 'bytes'], [
                dfxCadcLogic.address,
                DFX_CADC_PROXY_ADMIN,
                calldata
            ])
        }
    };

    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const outputPath = path.join(__dirname, new Date().getTime().toString() + `_deployed_dfxcadc.json`);
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