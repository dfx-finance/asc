import fs from 'fs'
import path from 'path'
import ethers from 'ethers'
import { fileURLToPath } from 'url';
import { wallet, deployContract } from './common.js'

import DfxCadLogicV1Artifact from '../out/DfxCadLogicV1.sol/DfxCadLogicV1.json'

const main = async () => {
    const LogicFactory = new ethers.ContractFactory(
        DfxCadLogicV1Artifact.abi, DfxCadLogicV1Artifact.bytecode.object, wallet
    )

    // 1. Deploy logic
    const dfxCadLogicV1 = await deployContract({
        name: 'DfxCadLogicV1Artifact',
        deployer: wallet,
        factory: LogicFactory,
        args: [],
        opts: {
            gasLimit: 3040761
        }
    })

    const output = {
        dfxCadLogicV1: dfxCadLogicV1.address,
    };

    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const outputPath = path.join(__dirname, new Date().getTime().toString() + `_deployed_dfxcadlogicv1.json`);
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