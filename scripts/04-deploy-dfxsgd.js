import fs from 'fs'
import path from 'path'
import ethers from 'ethers'
import { fileURLToPath } from 'url';
import { parseUnits } from '@ethersproject/units'
import { wallet, deployContract } from './common.js'

import DfxSgdTwapArtifact from '../out/DfxSgdTWAP.sol/DfxSgdTWAP.json'
import DfxSgdLogicArtifact from '../out/DfxSgdLogic.sol/DfxSgdLogic.json'
import ASCUpgradableProxyArtifact from '../out/ASCUpgradableProxy.sol/ASCUpgradableProxy.json'

// Access controller
const DFX_GOV_MULTISIG = '0x27E843260c71443b4CC8cB6bF226C3f77b9695AF'
const DFX_ACCESS_CONTROLLER_MULTISIG = '0xc9f05fa7049b32712c5d6675ebded167150475c4'
const DFX_TREASURY_MULTISIG = '0x26f539A0fE189A7f228D7982BF10Bc294FA9070c'

// Manages access control in twap
const TWAP_ROLE_ADMIN = DFX_ACCESS_CONTROLLER_MULTISIG

// Proxy admin is only used for upgrading proxy logic
const DFX_SGD_PROXY_ADMIN = DFX_GOV_MULTISIG

const DFX_SGD_NAME = "dfxSGD"
const DFX_SGD_SYMBOL = "dfxSGD"
const DFX_SGD_ROLE_ADMIN = DFX_ACCESS_CONTROLLER_MULTISIG // DFX_CADC_ADMIN is used to manage (all) roles
const DFX_SGD_FEE_RECIPIENT = DFX_TREASURY_MULTISIG
const DFX_SGD_MINT_BURN_FEE = parseUnits('0.005') // 0.5%
const XSGD_RATIO = parseUnits('0.95') // 95%
const DFX_RATIO = parseUnits('0.05') // 5%
const POKE_RATIO_DELTA = parseUnits('0.005') // 0.5%

const main = async () => {
    const TwapFactory = new ethers.ContractFactory(
        DfxSgdTwapArtifact.abi, DfxSgdTwapArtifact.bytecode.object, wallet
    )
    const LogicFactory = new ethers.ContractFactory(
        DfxSgdLogicArtifact.abi, DfxSgdLogicArtifact.bytecode.object, wallet
    )
    const UpgradableProxyFactory = new ethers.ContractFactory(
        ASCUpgradableProxyArtifact.abi, ASCUpgradableProxyArtifact.bytecode.object, wallet
    )

    // // 1. Deploy TWAP
    const dfxSgdTwap = await deployContract({
        name: 'DfxSgdTWAP',
        deployer: wallet,
        factory: TwapFactory,
        args: [TWAP_ROLE_ADMIN],
        opts: {
            gasLimit: 2017090
        }
    })

    // 2. Deploy logic
    const dfxSgdLogic = await deployContract({
        name: 'DfxSgdLogic',
        deployer: wallet,
        factory: LogicFactory,
        args: [],
        opts: {
            gasLimit: 3040761
        }
    })

    // 3. Deploy ASCUpgradableProxy with the encoded args
    const calldata = LogicFactory.interface.encodeFunctionData("initialize", [
        DFX_SGD_NAME, DFX_SGD_SYMBOL, DFX_SGD_ROLE_ADMIN, DFX_SGD_FEE_RECIPIENT, DFX_SGD_MINT_BURN_FEE, dfxSgdTwap.address, XSGD_RATIO, DFX_RATIO, POKE_RATIO_DELTA
    ])
    const dfxSgdProxy = await deployContract({
        name: 'DfxSgd',
        deployer: wallet,
        factory: UpgradableProxyFactory,
        args: [
            dfxSgdLogic.address,
            DFX_SGD_PROXY_ADMIN,
            calldata
        ],
        opts: {
            gasLimit: 1667809
        }
    })

    const output = {
        dfxSgdProxy: dfxSgdProxy.address,
        dfxSgdLogic: dfxSgdLogic.address,
        dfxSgdTwap: dfxSgdTwap.address,
        calldata: {
            dfxSgdTwap: ethers.utils.defaultAbiCoder.encode(['address'], [
                TWAP_ROLE_ADMIN,
            ]),
            dfxSgdProxy: ethers.utils.defaultAbiCoder.encode(['address', 'address', 'bytes'], [
                dfxSgdLogic.address,
                DFX_SGD_PROXY_ADMIN,
                calldata
            ])
        }
    };

    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const outputPath = path.join(__dirname, new Date().getTime().toString() + `_deployed_dfxsgd.json`);
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