// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

abstract contract IDfxOracle {
    function read() public virtual returns (uint256);
}