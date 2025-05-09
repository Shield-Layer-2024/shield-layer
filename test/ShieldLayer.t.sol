// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "../contracts/interfaces/IShieldLayer.sol";
import "../contracts/RewardProxy.sol";
import "../contracts/ShieldLayer.sol";
import "../contracts/ShieldLayerSilo.sol";
import "../contracts/USLT.sol";
import "../contracts/stUSLTv2.sol";
import "../contracts/mock/MockUSDT.sol";

contract ShieldLayerTest is Test {
  MockUSDT public usdtToken;
  USLT public usltToken;
  stUSLTv2 public stusltToken;

  ShieldLayer public shieldlayer;
  ShieldLayerSilo public shieldlayerSilo;

  RewardProxy public rewardProxy;

  uint256 _testerPrivateKey = 0xA11CE;
  uint256 _custodianPrivateKey = 0xA14CE;
  uint256 _rewarderPrivateKey = 0xB44DE;

  address public tester;
  address public custodian;
  address public rewarder;

  bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  function setUp() public virtual {
    tester = vm.addr(_testerPrivateKey);
    custodian = vm.addr(_custodianPrivateKey);
    rewarder = vm.addr(_rewarderPrivateKey);

    usdtToken = new MockUSDT();
    usltToken = new USLT();
    shieldlayerSilo = new ShieldLayerSilo();
    stusltToken = new stUSLTv2(usltToken, shieldlayerSilo);
    shieldlayer = new ShieldLayer(usltToken, stusltToken, 2000000000000000000000000, 2000000000000000000000000);
    rewardProxy = new RewardProxy(usltToken, stusltToken, shieldlayer);

    usltToken.grantRole(CONTROLLER_ROLE, address(shieldlayer));
    usltToken.grantRole(CONTROLLER_ROLE, address(rewardProxy));
    stusltToken.grantRole(CONTROLLER_ROLE, address(shieldlayer));
    shieldlayerSilo.grantRole(CONTROLLER_ROLE, address(stusltToken));
    stusltToken.grantRole(REWARDER_ROLE, address(rewardProxy));
    rewardProxy.grantRole(REWARDER_ROLE, rewarder);

    shieldlayer.addSupportedAsset(address(usdtToken), 1e12);
    shieldlayer.setCustodianAddress(custodian);
    stusltToken.setCooldownDuration(7 days);

    usdtToken.mint(1e36, tester);
    usdtToken.mint(1e36, rewarder);
  }

  function testMint() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldlayer), 1e36);
    shieldlayer.mint(address(usdtToken), 1e6);
    vm.stopPrank();

    assertEq(usltToken.balanceOf(tester), 1e6 * 1e12);
  }

  function testCantRedeemInsufficientAsset() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldlayer), 1e6);
    shieldlayer.mint(address(usdtToken), 1e6);
    vm.stopPrank();

    vm.prank(tester);
    vm.expectRevert(abi.encodeWithSelector(IShieldLayer.InsufficientAsset.selector));
    shieldlayer.redeem(address(usdtToken), 1e18);
  }

  function testMintAndStake() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldlayer), 1e36);
    usltToken.approve(address(stusltToken), 1e36);
    shieldlayer.mintAndStake(address(usdtToken), 1e6);
    vm.stopPrank();

    assertEq(usltToken.balanceOf(tester), 0);
    assertEq(stusltToken.balanceOf(tester), 1e18);
  }

  function testUnstake() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldlayer), 1e36);
    usltToken.approve(address(stusltToken), 1e36);
    shieldlayer.mintAndStake(address(usdtToken), 1e6);

    stusltToken.approve(address(shieldlayer), 1e18);
    shieldlayer.cooldownShares(1e18);

    vm.warp(block.timestamp + 8 days);

    shieldlayer.unstake();
    vm.stopPrank();

    assertEq(usltToken.balanceOf(tester), 1e18);
  }

  function testRedeem() public {
    uint256 balance = usdtToken.balanceOf(tester);

    vm.startPrank(tester);
    usdtToken.approve(address(shieldlayer), 1e6);
    shieldlayer.mint(address(usdtToken), 1e6);
    vm.stopPrank();

    vm.prank(custodian);
    usdtToken.transfer(address(shieldlayer), 1e6);

    vm.startPrank(tester);
    usltToken.approve(address(shieldlayer), 1e18);
    shieldlayer.redeem(address(usdtToken), 1e18);
    vm.stopPrank();

    assertEq(usdtToken.balanceOf(tester), balance);
  }

  function testTransferInReward() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldlayer), 1e18);
    usltToken.approve(address(stusltToken), 1e18);
    shieldlayer.mintAndStake(address(usdtToken), 1e6);
    vm.stopPrank();

    vm.startPrank(rewarder);
    usdtToken.approve(address(rewardProxy), 1e6);
    rewardProxy.transferInRewards(usdtToken, 1e6);
    console.logUint(stusltToken.previewRedeem(1e18));
    vm.warp(block.timestamp + 1 days);

    usdtToken.approve(address(rewardProxy), 2e6);
    rewardProxy.transferInRewards(usdtToken, 2e6);
    console.logUint(stusltToken.previewRedeem(1e18));
    vm.warp(block.timestamp + 1 days);

    usdtToken.approve(address(rewardProxy), 3e6);
    rewardProxy.transferInRewards(usdtToken, 3e6);
    console.logUint(stusltToken.previewRedeem(1e18));
    vm.stopPrank();
  }
}
