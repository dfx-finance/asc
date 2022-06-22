// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@forge-std/Script.sol";
import "../src/dfx-cadc/DfxCadLogicV1.sol";
import "../src/test/lib/Address.sol";

contract RecoverScript is Script {
    function run() external {
        vm.startBroadcast();

        DfxCadLogicV1 logic = DfxCadLogicV1(Mainnet.DFX_CAD);
        // logic.execute(Mainnet.DFX_CAD_TREASURY, _data);

        vm.stopBroadcast();
    }
}
