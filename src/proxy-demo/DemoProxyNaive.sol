// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract DemoProxyNaive {
    address public implementation;

    function setImplementation(address _implementation) public {
        implementation = _implementation;
    }

    function getImplementation() public view returns (address) {
        return implementation;
    }

    fallback() external {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            let result := delegatecall(
                gas(),
                sload(implementation.slot),
                ptr,
                calldatasize(),
                0,
                0
            )

            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }
    }
}
