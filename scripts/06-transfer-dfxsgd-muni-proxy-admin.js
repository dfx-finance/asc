/*
 * Script updates Proxy Admin from deployer address to DFX Multisig
 */
import ethers from 'ethers';
import { wallet } from './common.js';
import ASCUpgradableProxyArtifact from '../out/ASCUpgradableProxy.sol/ASCUpgradableProxy.json';
import chalk from 'chalk';

// MUNI dfxSGD/XSGD Proxy
const PROXY = "";

// Access controller
const DFX_GOV_MULTISIG = "0x27E843260c71443b4CC8cB6bF226C3f77b9695AF";

const main = async () => {
    const muniProxy = new ethers.Contract(PROXY, ASCUpgradableProxyArtifact.abi, wallet);
    
    const oldAdmin = await muniProxy.getAdmin();
    await muniProxy.changeAdmin(DFX_GOV_MULTISIG);
    const newAdmin = await muniProxy.getAdmin();
    
    chalk.grey(`=========================================`);
    console.log(`Proxy admin updated from ${oldAdmin} -> ${newAdmin}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });