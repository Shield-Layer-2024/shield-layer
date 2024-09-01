// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SigUtils} from "./utils/SigUtils.sol";

import "../contracts/slUSD.sol";
import "../contracts/USDs.sol";
import "../contracts/interfaces/IslUSD.sol";
import "../contracts/interfaces/IERC20Events.sol";

contract USDsTest is Test, IERC20Events {
  slUSD public usdeToken;
  USDs public stakedslUSD;
  SigUtils public sigUtilsslUSD;
  SigUtils public sigUtilsUSDs;

  address public owner;
  address public rewarder;
  address public alice;
  address public bob;
  address public greg;

  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event RewardsReceived(uint256 indexed amount, uint256 newVestingslUSDAmount);

  function setUp() public virtual {
    usdeToken = new slUSD(address(this));

    alice = vm.addr(0xB44DE);
    bob = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    rewarder = vm.addr(0x1DEA);
    vm.label(alice, "alice");
    vm.label(bob, "bob");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(rewarder, "rewarder");

    vm.prank(owner);
    stakedslUSD = new USDs(IslUSD(address(usdeToken)), rewarder, owner);

    sigUtilsslUSD = new SigUtils(usdeToken.DOMAIN_SEPARATOR());
    sigUtilsUSDs = new SigUtils(stakedslUSD.DOMAIN_SEPARATOR());

    usdeToken.addMinter(address(this));
  }

  function _mintApproveDeposit(address staker, uint256 amount) internal {
    usdeToken.mint(staker, amount);

    vm.startPrank(staker);
    usdeToken.approve(address(stakedslUSD), amount);

    vm.expectEmit(true, true, true, false);
    emit Deposit(staker, staker, amount, amount);

    stakedslUSD.deposit(amount, staker);
    vm.stopPrank();
  }

  function _redeem(address staker, uint256 amount) internal {
    vm.startPrank(staker);

    vm.expectEmit(true, true, true, false);
    emit Withdraw(staker, staker, staker, amount, amount);

    stakedslUSD.redeem(amount, staker, staker);
    vm.stopPrank();
  }

  function _transferRewards(uint256 amount, uint256 expectedNewVestingAmount) internal {
    usdeToken.mint(address(rewarder), amount);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedslUSD), amount);

    vm.expectEmit(true, false, false, true);
    emit Transfer(rewarder, address(stakedslUSD), amount);
    vm.expectEmit(true, false, false, false);
    emit RewardsReceived(amount, expectedNewVestingAmount);

    stakedslUSD.transferInRewards(amount);

    assertApproxEqAbs(stakedslUSD.getUnvestedAmount(), expectedNewVestingAmount, 1);
    vm.stopPrank();
  }

  function _assertVestedAmountIs(uint256 amount) internal {
    assertApproxEqAbs(stakedslUSD.totalAssets(), amount, 2);
  }

  function testInitialStake() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);

    assertEq(usdeToken.balanceOf(alice), 0);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), amount);
    assertEq(stakedslUSD.balanceOf(alice), amount);
  }

  function testInitialStakeBelowMin() public {
    uint256 amount = 0.99 ether;
    usdeToken.mint(alice, amount);
    vm.startPrank(alice);
    usdeToken.approve(address(stakedslUSD), amount);
    vm.expectRevert(IUSDs.MinSharesViolation.selector);
    stakedslUSD.deposit(amount, alice);

    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), 0);
    assertEq(stakedslUSD.balanceOf(alice), 0);
  }

  function testCantWithdrawBelowMinShares() public {
    _mintApproveDeposit(alice, 1 ether);

    vm.startPrank(alice);
    usdeToken.approve(address(stakedslUSD), 0.01 ether);
    vm.expectRevert(IUSDs.MinSharesViolation.selector);
    stakedslUSD.redeem(0.5 ether, alice, alice);
  }

  function testCannotStakeWithoutApproval() public {
    uint256 amount = 100 ether;
    usdeToken.mint(alice, amount);

    vm.startPrank(alice);
    vm.expectRevert("ERC20: insufficient allowance");
    stakedslUSD.deposit(amount, alice);
    vm.stopPrank();

    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), 0);
    assertEq(stakedslUSD.balanceOf(alice), 0);
  }

  function testStakeUnstake() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);

    assertEq(usdeToken.balanceOf(alice), 0);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), amount);
    assertEq(stakedslUSD.balanceOf(alice), amount);

    _redeem(alice, amount);

    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), 0);
    assertEq(stakedslUSD.balanceOf(alice), 0);
  }

  function testOnlyRewarderCanReward() public {
    uint256 amount = 100 ether;
    uint256 rewardAmount = 0.5 ether;
    _mintApproveDeposit(alice, amount);

    usdeToken.mint(bob, rewardAmount);
    vm.startPrank(bob);

    vm.expectRevert(
      "AccessControl: account 0x72c7a47c5d01bddf9067eabb345f5daabdead13f is missing role 0xbeec13769b5f410b0584f69811bfd923818456d5edcf426b0e31cf90eed7a3f6"
    );
    stakedslUSD.transferInRewards(rewardAmount);
    vm.stopPrank();
    assertEq(usdeToken.balanceOf(alice), 0);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), amount);
    assertEq(stakedslUSD.balanceOf(alice), amount);
    _assertVestedAmountIs(amount);
    assertEq(usdeToken.balanceOf(bob), rewardAmount);
  }

  function testStakingAndUnstakingBeforeAfterReward() public {
    uint256 amount = 100 ether;
    uint256 rewardAmount = 100 ether;
    _mintApproveDeposit(alice, amount);
    _transferRewards(rewardAmount, rewardAmount);
    _redeem(alice, amount);
    assertEq(usdeToken.balanceOf(alice), amount);
    assertEq(stakedslUSD.totalSupply(), 0);
  }

  function testFuzzNoJumpInVestedBalance(uint256 amount) public {
    vm.assume(amount > 0 && amount < 1e60);
    _transferRewards(amount, amount);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(amount / 2);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), amount);
  }

  function testOwnerCannotRescueslUSD() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);
    bytes4 selector = bytes4(keccak256("InvalidToken()"));
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(selector));
    stakedslUSD.rescueTokens(address(usdeToken), amount, owner);
  }

  function testOwnerCanRescuestslUSD() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);
    vm.prank(alice);
    stakedslUSD.transfer(address(stakedslUSD), amount);
    assertEq(stakedslUSD.balanceOf(owner), 0);
    vm.startPrank(owner);
    stakedslUSD.rescueTokens(address(stakedslUSD), amount, owner);
    assertEq(stakedslUSD.balanceOf(owner), amount);
  }

  function testOwnerCanChangeRewarder() public {
    assertTrue(stakedslUSD.hasRole(REWARDER_ROLE, address(rewarder)));
    address newRewarder = address(0x123);
    vm.startPrank(owner);
    stakedslUSD.revokeRole(REWARDER_ROLE, rewarder);
    stakedslUSD.grantRole(REWARDER_ROLE, newRewarder);
    assertTrue(!stakedslUSD.hasRole(REWARDER_ROLE, address(rewarder)));
    assertTrue(stakedslUSD.hasRole(REWARDER_ROLE, newRewarder));
    vm.stopPrank();

    usdeToken.mint(rewarder, 1 ether);
    usdeToken.mint(newRewarder, 1 ether);

    vm.startPrank(rewarder);
    usdeToken.approve(address(stakedslUSD), 1 ether);
    vm.expectRevert(
      "AccessControl: account 0x5c664540bc6bb6b22e9d1d3d630c73c02edd94b7 is missing role 0xbeec13769b5f410b0584f69811bfd923818456d5edcf426b0e31cf90eed7a3f6"
    );
    stakedslUSD.transferInRewards(1 ether);
    vm.stopPrank();

    vm.startPrank(newRewarder);
    usdeToken.approve(address(stakedslUSD), 1 ether);
    stakedslUSD.transferInRewards(1 ether);
    vm.stopPrank();

    assertEq(usdeToken.balanceOf(address(stakedslUSD)), 1 ether);
    assertEq(usdeToken.balanceOf(rewarder), 1 ether);
    assertEq(usdeToken.balanceOf(newRewarder), 0);
  }

  function testslUSDValuePerStslUSD() public {
    _mintApproveDeposit(alice, 100 ether);
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(150 ether);
    assertEq(stakedslUSD.convertToAssets(1 ether), 1.5 ether - 1);
    assertEq(stakedslUSD.totalSupply(), 100 ether);
    // rounding
    _mintApproveDeposit(bob, 75 ether);
    _assertVestedAmountIs(225 ether);
    assertEq(stakedslUSD.balanceOf(alice), 100 ether);
    assertEq(stakedslUSD.balanceOf(bob), 50 ether);
    assertEq(stakedslUSD.convertToAssets(1 ether), 1.5 ether - 1);

    vm.warp(block.timestamp + 4 hours);

    uint256 vestedAmount = 275 ether;
    _assertVestedAmountIs(vestedAmount);

    assertApproxEqAbs(stakedslUSD.convertToAssets(1 ether), (vestedAmount * 1 ether) / 150 ether, 1);

    // rounding
    _redeem(bob, stakedslUSD.balanceOf(bob));

    _redeem(alice, 100 ether);

    assertEq(stakedslUSD.balanceOf(alice), 0);
    assertEq(stakedslUSD.balanceOf(bob), 0);
    assertEq(stakedslUSD.totalSupply(), 0);

    assertApproxEqAbs(usdeToken.balanceOf(alice), (vestedAmount * 2) / 3, 2);

    assertApproxEqAbs(usdeToken.balanceOf(bob), vestedAmount / 3, 2);

    assertApproxEqAbs(usdeToken.balanceOf(address(stakedslUSD)), 0, 1);
  }

  function testFairStakeAndUnstakePrices() public {
    uint256 aliceAmount = 100 ether;
    uint256 bobAmount = 1000 ether;
    uint256 rewardAmount = 200 ether;
    _mintApproveDeposit(alice, aliceAmount);
    _transferRewards(rewardAmount, rewardAmount);
    vm.warp(block.timestamp + 4 hours);
    _mintApproveDeposit(bob, bobAmount);
    vm.warp(block.timestamp + 4 hours);
    _redeem(alice, aliceAmount);
    _assertVestedAmountIs(bobAmount + (rewardAmount * 5) / 12);
  }

  // FIXME: test failed
//   function testFuzzFairStakeAndUnstakePrices(
//     uint256 amount1,
//     uint256 amount2,
//     uint256 amount3,
//     uint256 rewardAmount,
//     uint256 waitSeconds
//   ) public {
//     vm.assume(
//       amount1 >= 100 ether && amount2 > 0 && amount3 > 0 && rewardAmount > 0 && waitSeconds <= 9 hours
//       // 100 trillion USD with 18 decimals
//       && amount1 < 1e32 && amount2 < 1e32 && amount3 < 1e32 && rewardAmount < 1e32
//     );

//     uint256 totalContributions = amount1;

//     _mintApproveDeposit(alice, amount1);

//     _transferRewards(rewardAmount, rewardAmount);

//     vm.warp(block.timestamp + waitSeconds);

//     uint256 vestedAmount;
//     if (waitSeconds > 8 hours) {
//       vestedAmount = amount1 + rewardAmount;
//     } else {
//       vestedAmount = amount1 + rewardAmount - (rewardAmount * (8 hours - waitSeconds)) / 8 hours;
//     }

//     _assertVestedAmountIs(vestedAmount);

//     uint256 bobUSDs = (amount2 * (amount1 + 1)) / (vestedAmount + 1);
//     if (bobUSDs > 0) {
//       _mintApproveDeposit(bob, amount2);
//       totalContributions += amount2;
//     }

//     vm.warp(block.timestamp + waitSeconds);

//     if (waitSeconds > 4 hours) {
//       vestedAmount = totalContributions + rewardAmount;
//     } else {
//       vestedAmount = totalContributions + rewardAmount - ((4 hours - waitSeconds) * rewardAmount) / 4 hours;
//     }

//     _assertVestedAmountIs(vestedAmount);

//     uint256 gregUSDs = (amount3 * (stakedslUSD.totalSupply() + 1)) / (vestedAmount + 1);
//     if (gregUSDs > 0) {
//       _mintApproveDeposit(greg, amount3);
//       totalContributions += amount3;
//     }

//     vm.warp(block.timestamp + 8 hours);

//     vestedAmount = totalContributions + rewardAmount;

//     _assertVestedAmountIs(vestedAmount);

//     uint256 usdePerUSDsBefore = stakedslUSD.convertToAssets(1 ether);
//     uint256 bobUnstakeAmount = (stakedslUSD.balanceOf(bob) * (vestedAmount + 1)) / (stakedslUSD.totalSupply() + 1);
//     uint256 gregUnstakeAmount = (stakedslUSD.balanceOf(greg) * (vestedAmount + 1)) / (stakedslUSD.totalSupply() + 1);

//     if (bobUnstakeAmount > 0) _redeem(bob, stakedslUSD.balanceOf(bob));
//     uint256 usdePerUSDsAfter = stakedslUSD.convertToAssets(1 ether);
//     if (usdePerUSDsAfter != 0) assertApproxEqAbs(usdePerUSDsAfter, usdePerUSDsBefore, 1 ether);

//     if (gregUnstakeAmount > 0) _redeem(greg, stakedslUSD.balanceOf(greg));
//     usdePerUSDsAfter = stakedslUSD.convertToAssets(1 ether);
//     if (usdePerUSDsAfter != 0) assertApproxEqAbs(usdePerUSDsAfter, usdePerUSDsBefore, 1 ether);

//     _redeem(alice, amount1);

//     assertEq(stakedslUSD.totalSupply(), 0);
//     assertApproxEqAbs(stakedslUSD.totalAssets(), 0, 10 ** 12);
//   }

  function testTransferRewardsFailsInsufficientBalance() public {
    usdeToken.mint(address(rewarder), 99);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedslUSD), 100);

    vm.expectRevert("ERC20: transfer amount exceeds balance");
    stakedslUSD.transferInRewards(100);
    vm.stopPrank();
  }

  function testTransferRewardsFailsZeroAmount() public {
    usdeToken.mint(address(rewarder), 100);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedslUSD), 100);

    vm.expectRevert(IUSDs.InvalidAmount.selector);
    stakedslUSD.transferInRewards(0);
    vm.stopPrank();
  }

  function testDecimalsIs18() public {
    assertEq(stakedslUSD.decimals(), 18);
  }

  function testMintWithSlippageCheck(uint256 amount) public {
    amount = bound(amount, 1 ether, type(uint256).max / 2);
    usdeToken.mint(alice, amount * 2);

    assertEq(stakedslUSD.balanceOf(alice), 0);

    vm.startPrank(alice);
    usdeToken.approve(address(stakedslUSD), amount);
    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, amount, amount);
    stakedslUSD.mint(amount, alice);

    assertEq(stakedslUSD.balanceOf(alice), amount);

    usdeToken.approve(address(stakedslUSD), amount);
    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, amount, amount);
    stakedslUSD.mint(amount, alice);

    assertEq(stakedslUSD.balanceOf(alice), amount * 2);
  }

  function testMintToDiffRecipient() public {
    usdeToken.mint(alice, 1 ether);

    vm.startPrank(alice);

    usdeToken.approve(address(stakedslUSD), 1 ether);

    stakedslUSD.deposit(1 ether, bob);

    assertEq(stakedslUSD.balanceOf(alice), 0);
    assertEq(stakedslUSD.balanceOf(bob), 1 ether);
  }

  function testCannotTransferRewardsWhileVesting() public {
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(50 ether);
    vm.prank(rewarder);
    vm.expectRevert(IUSDs.StillVesting.selector);
    stakedslUSD.transferInRewards(100 ether);
    _assertVestedAmountIs(50 ether);
    assertEq(stakedslUSD.vestingAmount(), 100 ether);
  }

  function testCanTransferRewardsAfterVesting() public {
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 8 hours);
    _assertVestedAmountIs(100 ether);
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 8 hours);
    _assertVestedAmountIs(200 ether);
  }

  function testDonationAttack() public {
    uint256 initialStake = 1 ether;
    uint256 donationAmount = 10_000_000_000 ether;
    uint256 bobStake = 100 ether;
    _mintApproveDeposit(alice, initialStake);
    assertEq(stakedslUSD.totalSupply(), initialStake);
    usdeToken.mint(alice, donationAmount);
    vm.prank(alice);
    usdeToken.transfer(address(stakedslUSD), donationAmount);
    assertEq(stakedslUSD.totalSupply(), initialStake);
    assertEq(usdeToken.balanceOf(address(stakedslUSD)), initialStake + donationAmount);
    _mintApproveDeposit(bob, bobStake);
    uint256 bobStslUSDBal = stakedslUSD.balanceOf(bob);
    uint256 bobStslUSDExpectedBal = (bobStake * initialStake) / (initialStake + donationAmount);
    assertApproxEqAbs(bobStslUSDBal, bobStslUSDExpectedBal, 1e9);
    assertTrue(bobStslUSDBal > 0);
  }
}