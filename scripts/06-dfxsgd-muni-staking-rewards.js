import chalk from 'chalk'
import ethers from 'ethers'
import fs from 'fs'
import path from 'path'
import { wallet, deployContract } from './common.js'

import StakingRewardsArtifact from '../out/StakingRewards.sol/StakingRewards.json';
import { fileURLToPath } from 'url'

const DFX = "0x888888435fde8e7d4c54cab67f206e4199454c60";
const MUNI_DFXSGD_XSGD = "";
const DFX_TREASURY = "0x26f539A0fE189A7f228D7982BF10Bc294FA9070c";

async function main() {
    console.log(
        chalk.blue(`>>>>>>>>>>>> Deployer: ${wallet.address} <<<<<<<<<<<<`)
    );

    const StakingRewardsFactory = new ethers.ContractFactory(
        StakingRewardsArtifact.abi, StakingRewardsArtifact.bytecode.object, wallet
    );

    const muniStakingRewards = await deployContract({
        name: "muniDfxSgdStakingRewards",
        deployer: wallet,
        factory: StakingRewardsFactory,
        args: [DFX_TREASURY, DFX, MUNI_DFXSGD_XSGD],
        opts: {
            gasLimit: 2000000,
        },
    });

    const output = {
        muniStakingRewards: muniStakingRewards.address,
        calldata: {
            stakingRewards: ethers.utils.defaultAbiCoder.encode(
              ["address", "address", "address"],
              [DFX_TREASURY, DFX, MUNI_DFXSGD_XSGD]
            ),
          },        
    };

    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const outputPath = path.join(
        __dirname,
        new Date().getTime().toString() + `-muni-dfxsgd-staking-rewards_deployed.json`
    );
    fs.writeFileSync(outputPath, JSON.stringify(output, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });