// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(address _a, uint256 _b) public {
        _mint(_a, _b);
    }

    // function approve(address _owner, address _spender, uint256 _amount) public {
    //     _approve(_owner, _spender, _amount);
    // }

    // function balanceOf(address _account) public {
    //     return _balances[_account];
    // }
}
