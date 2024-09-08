// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import "../contracts/SLUSD.sol";
import "../contracts/USDsV2.sol";
import "../contracts/ShieldLayer.sol";
import "../contracts/ShieldLayerSilo.sol";
import "../contracts/mock/MockUSDT.sol";

contract ShieldLayerTest is Test {
  MockToken public usdtToken;
  SLUSD public slusdToken;
  ShieldLayerSilo public silo;
  USDsV2 public usdsToken;
  ShieldLayer public shieldLayer;

  uint256 _testerPrivateKey = 0xA11CE;
  uint256 _custodianPrivateKey = 0xA14CE;
  // uint256 _minterPrivateKey = 0xB44DE;
  // uint256 _newMinterPrivateKey = 0xB45DE;

  address public tester;
  address public custodian;

  bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  function setUp() public virtual {
    tester = vm.addr(_testerPrivateKey);
    custodian = vm.addr(_custodianPrivateKey);

    usdtToken = new MockToken("USDT", "USDT", 6, tester);
    slusdToken = new SLUSD();
    silo = new ShieldLayerSilo();
    usdsToken = new USDsV2(slusdToken, silo);
    shieldLayer = new ShieldLayer(slusdToken, usdsToken, 2000000000000000000000000, 2000000000000000000000000);

    slusdToken.grantRole(CONTROLLER_ROLE, address(shieldLayer));
    usdsToken.grantRole(CONTROLLER_ROLE, address(shieldLayer));
    silo.grantRole(CONTROLLER_ROLE, address(usdsToken));

    shieldLayer.addSupportedAsset(address(usdtToken), 10e12);
    shieldLayer.setCustodianAddress(custodian);

    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 10e36);
    slusdToken.approve(address(usdsToken), 10e36);
    vm.stopPrank();
  }

  function testMint() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 10e36);

    shieldLayer.mint(address(usdtToken), 10e6);
    vm.stopPrank();

    assertEq(slusdToken.balanceOf(tester), 10e6 * 10e12);
  }

  function testMintAndDeposit() public {
    vm.startPrank(tester);
    usdtToken.approve(address(shieldLayer), 10e36);
    slusdToken.approve(address(usdsToken), 10e36);

    shieldLayer.mintAndDeposit(address(usdtToken), 10e6);
    vm.stopPrank();

    assertEq(slusdToken.balanceOf(tester), 0);
    assertEq(usdsToken.balanceOf(tester), 10e6 * 10e12);
  }
}
