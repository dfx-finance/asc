pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimelockDeploy is Script {
    address public constant DFX_MULTISIG = 0xc9f05fa7049b32712c5d6675ebded167150475c4;

    function run() external {
        vm.startBroadcast();

        TimelockController timelock = new TimelockController(
            1 weeks,
            proposers,
            executors
        );
    }
}