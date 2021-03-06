// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IDfxCurve {
    function originSwap(
        address _origin,
        address _target,
        uint256 _originAmount,
        uint256 _minTargetAmount,
        uint256 _deadline
    ) external returns (uint256 targetAmount_);

    function viewOriginSwap(
        address _origin,
        address _target,
        uint256 _originAmount
    ) external view returns (uint256 targetAmount_);
}
