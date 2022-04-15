// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./MUNILogicV1.sol";

contract MUNINewLogic is MUNILogicV1 {
    function newLogic() public pure returns (string memory) {
        return "new logic here";
    }
}
