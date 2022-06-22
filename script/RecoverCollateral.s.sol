// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@forge-std/Script.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../src/dfx-cadc/DfxCadLogicV1.sol";
import "../src/test/lib/Address.sol";

/*
 * Run by:
 * 1. Create .env file with RPC_URL and PRIVATE_KEY (from anvil) and source it
 * 2. anvil -f $RPC_URL --fork-block-number 14980100
 * 3. forge script script/RecoverCollateral.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY
 */

contract RecoverScript is Script {
    using SafeERC20 for IERC20;

    function run() external {
        // vm.startBroadcast();

        DfxCadLogicV1 logic = DfxCadLogicV1(Mainnet.DFX_CAD);
        IERC20 DFX = IERC20(Mainnet.DFX);

        // Build transaction to be executed from the context of the DfxCadLogic contract
        // Ex: DFX.safeTransfer(Mainnet.DFX_CAD_TREASURY, DFX.balanceOf(address(this)));
        bytes memory _data = abi.encodeWithSignature("transfer(address,uint256)", Mainnet.DFX_CAD_TREASURY, DFX.balanceOf(address(this)));
        logic.execute(Mainnet.DFX_CAD_TREASURY, _data);

        // vm.stopBroadcast();
    }
}
