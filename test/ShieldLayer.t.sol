// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "../contracts/interfaces/IShieldLayer.sol";
import "../contracts/SLUSD.sol";
import "../contracts/USDsV2.sol";
import "../contracts/ShieldLayer.sol";
import "../contracts/ShieldLayerSilo.sol";
import "../contracts/mock/MockUSDT.sol";

contract ShieldLayerTest is Test {
  MockUSDT public usdtToken;
  SLUSD public slusdToken;
  ShieldLayerSilo public silo;
  USDsV2 public usdsToken;
  ShieldLayer public shieldLayer;

  uint256 _testerPrivateKey = 0xA11CE;
  uint256 _custodianPrivateKey = 0xA14CE;
  uint256 _rewarderPrivateKey = 0xB44DE;
  // uint256 _newMinterPrivateKey = 0xB45DE;

  address public tester;
  address public custodian;
  address public rewarder;

  bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  function setUp() public virtual {
    tester = vm.addr(_testerPrivateKey);
    custodian = vm.addr(_custodianPrivateKey);

    usdtToken = new MockUSDT();
    slusdToken = new SLUSD();
    silo = new ShieldLayerSilo();
    usdsToken = new USDsV2(slusdToken, silo);
    shieldLayer = new ShieldLayer(slusdToken, usdsToken, 2000000000000000000000000, 2000000000000000000000000);

    slusdToken.grantRole(CONTROLLER_ROLE, address(shieldLayer));
    usdsToken.grantRole(CONTROLLER_ROLE, address(shieldLayer));
    usdsToken.grantRole(REWARDER_ROLE, rewarder);
    silo.grantRole(CONTROLLER_ROLE, address(usdsToken));

    shieldLayer.addSupportedAsset(address(usdtToken), 1e12);
    shieldLayer.setCustodianAddress(custodian);
    usdsToken.setCooldownDuration(7 days);
  }

  function testMint() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 1e36);
    shieldLayer.mint(address(usdtToken), 1e6);
    vm.stopPrank();

    assertEq(slusdToken.balanceOf(tester), 1e6 * 1e12);
  }

  function testCantRedeemInsufficientAsset() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 1e6);
    shieldLayer.mint(address(usdtToken), 1e6);
    vm.stopPrank();

    vm.prank(tester);
    vm.expectRevert(abi.encodeWithSelector(IShieldLayer.InsufficientAsset.selector));
    shieldLayer.redeem(address(usdtToken), 1e18);
  }

  function testMintAndStake() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 1e36);
    slusdToken.approve(address(usdsToken), 1e36);
    shieldLayer.mintAndStake(address(usdtToken), 1e6);
    vm.stopPrank();

    assertEq(slusdToken.balanceOf(tester), 0);
    assertEq(usdsToken.balanceOf(tester), 1e18);
  }

  function testUnstake() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 1e36);
    slusdToken.approve(address(usdsToken), 1e36);
    shieldLayer.mintAndStake(address(usdtToken), 1e6);

    usdsToken.approve(address(shieldLayer), 1e18);
    shieldLayer.cooldownShares(1e18);

    vm.warp(block.timestamp + 8 days);

    shieldLayer.unstake();
    vm.stopPrank();

    assertEq(slusdToken.balanceOf(tester), 1e18);
  }

  function testRedeem() public {
    uint256 balance = usdtToken.balanceOf(tester);

    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 1e6);
    shieldLayer.mint(address(usdtToken), 1e6);
    vm.stopPrank();

    vm.prank(custodian);
    usdtToken.transfer(address(shieldLayer), 1e6);

    vm.startPrank(tester);
    slusdToken.approve(address(shieldLayer), 1e18);
    shieldLayer.redeem(address(usdtToken), 1e18);
    vm.stopPrank();

    assertEq(usdtToken.balanceOf(tester), balance);
  }
}
