// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../lib/MockToken.sol";
import "../lib/MockUser.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import "../../liquidity-mining/StakingRewards.sol";

contract StakingRewardsTest is DSTest {
        
    StakingRewards stakingRewards;

    MockToken stakingToken;
    MockToken rewardToken;

    MockUser user1;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        stakingToken = new MockToken();
        rewardToken = new MockToken();

        user1 = new MockUser();

        stakingRewards = new StakingRewards(
            address(this),
            address(rewardToken),
            address(stakingToken)
        );

        rewardToken.mint(address(stakingRewards), 100e18);
        stakingToken.mint(address(user1), 100e18);

        // Approvals
        cheats.prank(address(user1));
        stakingToken.approve(address(stakingRewards), type(uint256).max);

        cheats.prank(address(user1));
        stakingRewards.stake(100e18);
    }

    function testFail_recover_staking_token() public {
        cheats.prank(address(this));
        stakingRewards.recoverERC20(address(stakingToken), 100e18);
    }

    function test_recover_token() public {
        cheats.prank(address(this));
        stakingRewards.recoverERC20(address(rewardToken), 100e18);
    }
}
