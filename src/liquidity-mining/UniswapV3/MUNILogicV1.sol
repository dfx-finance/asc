// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/*
    Inspired by https://github.com/gelatodigital/g-uni-v1-core/blob/master/contracts/GUniPool.sol#L135

    MUNI (Managed Uni)

    As of Uniswap V3, liquidity positions will be represented by an NFT.
    Managing LPs efficiently is within the protocols interest, such as
    concentrating liquidity between a certain range for like-minded pairs.

    MUNI will be responsible for managing said positions while issuing out a ERC20 token as a receipt
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./MUNIState.sol";

import "../../libraries/FullMath.sol";

contract MUNILogicV1 is MUNIState {
    using SafeERC20 for IERC20;

    // // Does this belong in `state` as a constant? State says it cannot accept immutables,
    // // but using constants sounded more expensive
    // IUniswapV3Pool public immutable pool;
    // IERC20 public immutable token0;
    // IERC20 public immutable token1;

    // **** Initializing functions ****

    // We don't need to check twice if the contract's initialized as
    // __ERC20_init does that check

    /// @param _owner address of Uniswap V3 pool
    /// @param _pool address of Uniswap V3 pool
    /// @param _managerFeeBPS proportion of fees earned that go to manager treasury
    /// note that the 4 above params are NOT UPDATEABLE AFTER INILIALIZATION
    /// @param _lowerTick initial lowerTick (only changeable with executiveRebalance)
    /// @param _upperTick initial upperTick (only changeable with executiveRebalance)
    /// @param _name name of MUNI
    /// @param _symbol symbol of MUNI token
    function initialize(
        address _owner,
        address _pool,
        uint16 _managerFeeBPS,
        int24 _lowerTick,
        int24 _upperTick,
        string memory _name,
        string memory _symbol        
    ) public initializer {
        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __Pausable_init();
        __ReentrancyGuard_init();

        _transferOwnership(_owner);

        // pool = IUniswapV3Pool(_pool);
        // token0 = IERC20(pool.token0());
        // token1 = IERC20(pool.token1());

        // managerFeeBPS = _managerFeeBPS;
        // lowerTick = _lowerTick;
        // upperTick = _upperTick;
    }

    
}
