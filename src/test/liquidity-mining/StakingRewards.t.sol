// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";

import "../lib/MockToken.sol";
import "../lib/MockUser.sol";
import "../lib/Address.sol";
import "../lib/CheatCodes.sol";

import "../../liquidity-mining/StakingRewards.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingRewardsTest is DSTest {
    using SafeMath for uint256;
        
    StakingRewards stakingRewards;

    TimelockController timelock; 

    MockToken stakingToken;
    MockToken rewardToken;    

    MockUser user1;
    MockUser user2;
    MockUser multisig;

    address[] proposers;
    address[] executors;

    // Cheatcodes
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        stakingToken = new MockToken();
        rewardToken = new MockToken();

        user1 = new MockUser();
        user2 = new MockUser();
        multisig = new MockUser();

        proposers = [address(multisig)];
        executors = [address(multisig)];

        // Set multisig address as the proposer and executors 
        // 1 week minimum for timelocks
        timelock = new TimelockController(
            1 weeks,
            proposers,
            executors
        );

        // Make timelock the owner of the staking contract
        stakingRewards = new StakingRewards(
            address(multisig),
            address(rewardToken),
            address(stakingToken)
        );

        // Set reward period to 1 month
        multisig.call(
            address(stakingRewards),
            abi.encodeWithSelector(
                stakingRewards.setRewardsDuration.selector,
                4 weeks
            )
        );

        // Transfer ownership
        multisig.call(
            address(stakingRewards),
            abi.encodeWithSelector(
                stakingRewards.transferOwnership.selector,
                address(timelock)
            )
        );

        // Mint tokens to respective users
        rewardToken.mint(address(stakingRewards), 100_000e18);
        stakingToken.mint(address(user1), 100e18);
        stakingToken.mint(address(user2), 200e18);

        // Propose notifying rewards to the timelock
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.schedule.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.notifyRewardAmount.selector, 100_000e18),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-notifyReward"),
                1 weeks
            )
        );

        cheats.warp(block.timestamp + 1 weeks + 1 seconds);

        // Execute notifying rewards to the timelock
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.execute.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.notifyRewardAmount.selector, 100_000e18),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-notifyReward")
            )
        );

        // Approvals and Staking
        cheats.startPrank(address(user1));
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(100e18);
        cheats.stopPrank();

        cheats.startPrank(address(user2));
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(200e18);
        cheats.stopPrank();

        // Increase time
        cheats.warp(block.timestamp + 10 minutes); 
    }

    function testFail_recover_staking_token() public {
        // Propose token recovery to the timelock
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.schedule.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.recoverERC20.selector, address(stakingToken), 100e18),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-recoverERC20"),
                1 weeks
            )
        );

        cheats.warp(block.timestamp + 1 weeks + 1 seconds);

        // Execute token recovery to the timelock
        // Cannot recover staking tokens
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.execute.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.recoverERC20.selector, address(stakingToken), 100e18),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-recoverERC20")
            )
        );
    }

    function test_recover_reward_token() public {
        // Propose token recovery to the timelock
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.schedule.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.recoverERC20.selector, address(rewardToken), 100e18),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-recoverERC20"),
                1 weeks
            )
        );

        cheats.warp(block.timestamp + 1 weeks + 1 seconds);

        // Execute token recovery to the timelock
        // Can recover reward tokens
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.execute.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.recoverERC20.selector, address(rewardToken), 100e18),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-recoverERC20")
            )
        );
    }

    function testFail_staking_while_paused() public {
        // Propose staking pause to the timelock
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.schedule.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.setPaused.selector, true),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-setPaused"),
                1 weeks
            )
        );

        cheats.warp(block.timestamp + 1 weeks + 1 seconds);

        // Execute token recovery to the timelock
        // Can recover reward tokens
        multisig.call(
            address(timelock),
            abi.encodeWithSelector(
                timelock.execute.selector, 
                address(stakingRewards),
                0,
                abi.encodeWithSelector(stakingRewards.setPaused.selector, true),
                bytes32(0),
                keccak256("dfxcadc-07-06-22-setPaused")
            )
        );

        stakingToken.mint(address(user1), 100e18);
        cheats.prank(address(user1));
        stakingRewards.stake(100e18);
    }

    function test_staking_while_not_paused() public {
        assertTrue(!stakingRewards.paused());

        stakingToken.mint(address(user1), 100e18);
        cheats.prank(address(user1));
        stakingRewards.stake(100e18);
    }

    function test_get_reward_logic() public {
        cheats.prank(address(user1));
        stakingRewards.getReward();
        cheats.prank(address(user2));
        stakingRewards.getReward();

        uint user1Bal = rewardToken.balanceOf(address(user1));
        uint user2Bal = rewardToken.balanceOf(address(user2));
        
        assertEq(user1Bal.mul(2), user2Bal);
    }
    
    function test_staking_logic() public {
        cheats.prank(address(user1));
        stakingRewards.getReward();
        cheats.prank(address(user2));
        stakingRewards.getReward();

        uint256 reward1 = rewardToken.balanceOf(address(user1));
        uint256 reward2 = rewardToken.balanceOf(address(user2));

        assertEq((reward1.mul(2)), reward2);
    }

    function test_withdraw_logic() public {
        cheats.prank(address(user1));
        stakingRewards.withdraw(100e18);
        cheats.prank(address(user2));
        stakingRewards.withdraw(200e18);

        uint256 stkBal1 = stakingToken.balanceOf(address(user1));
        uint256 stkBal2 = stakingToken.balanceOf(address(user2));

        uint256 reward1 = rewardToken.balanceOf(address(user1));
        uint256 reward2 = rewardToken.balanceOf(address(user2));

        assertEq((stkBal1.mul(2)), stkBal2);
        assertEq(reward1, 0);
        assertEq(reward2, 0);
    }

    function test_exit_logic() public {
        cheats.prank(address(user1));
        stakingRewards.exit();
        cheats.prank(address(user2));
        stakingRewards.exit();
        
        uint256 stkBal1 = stakingToken.balanceOf(address(user1));
        uint256 stkBal2 = stakingToken.balanceOf(address(user2));

        uint256 reward1 = rewardToken.balanceOf(address(user1));
        uint256 reward2 = rewardToken.balanceOf(address(user2));        

        assertEq(stkBal1.mul(2), stkBal2);
        assertEq(reward1.mul(2), reward2);
    }
}
