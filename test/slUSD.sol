// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable private-vars-leading-underscore  */

import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SigUtils} from "./utils/SigUtils.sol";

import "./utils/ShieldLayerMinting.utils.sol";
import "../contracts/slUSD.sol";

contract slUSDTest is Test, IslUSDDefinitions, ShieldLayerMintingUtils {
  slUSD internal _usdsToken;

  uint256 internal _ownerPrivateKey;
  uint256 internal _newOwnerPrivateKey;
  uint256 internal _minterPrivateKey;
  uint256 internal _newMinterPrivateKey;

  address internal _owner;
  address internal _newOwner;
  address internal _minter;
  address internal _newMinter;

  function setUp() public virtual override {
    _ownerPrivateKey = 0xA11CE;
    _newOwnerPrivateKey = 0xA14CE;
    _minterPrivateKey = 0xB44DE;
    _newMinterPrivateKey = 0xB45DE;

    _owner = vm.addr(_ownerPrivateKey);
    _newOwner = vm.addr(_newOwnerPrivateKey);
    _minter = vm.addr(_minterPrivateKey);
    _newMinter = vm.addr(_newMinterPrivateKey);

    vm.label(_minter, "minter");
    vm.label(_owner, "owner");
    vm.label(_newMinter, "_newMinter");
    vm.label(_newOwner, "newOwner");

    _usdsToken = new slUSD(_owner);
    vm.prank(_owner);
    _usdsToken.addMinter(_minter);
  }

  function testCorrectInitialConfig() public {
    assertEq(_usdsToken.owner(), _owner);
    assertTrue(_usdsToken.minters(_minter));
  }

  function testCantInitWithNoOwner() public {
    vm.expectRevert(ZeroAddressExceptionErr);
    new slUSD(address(0));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.prank(_owner);
    vm.expectRevert(CantRenounceOwnershipErr);
    _usdsToken.renounceOwnership();
    assertEq(_usdsToken.owner(), _owner);
    assertNotEq(_usdsToken.owner(), address(0));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(_owner);
    _usdsToken.transferOwnership(_newOwner);
    assertEq(_usdsToken.owner(), _owner);
    assertNotEq(_usdsToken.owner(), _newOwner);
  }

  function testCanTransferOwnership() public {
    vm.prank(_owner);
    _usdsToken.transferOwnership(_newOwner);
    vm.prank(_newOwner);
    _usdsToken.acceptOwnership();
    assertEq(_usdsToken.owner(), _newOwner);
    assertNotEq(_usdsToken.owner(), _owner);
  }

  function testCanCancelOwnershipChange() public {
    vm.startPrank(_owner);
    _usdsToken.transferOwnership(_newOwner);
    _usdsToken.transferOwnership(address(0));
    vm.stopPrank();

    vm.prank(_newOwner);
    vm.expectRevert("Ownable2Step: caller is not the new owner");
    _usdsToken.acceptOwnership();
    assertEq(_usdsToken.owner(), _owner);
    assertNotEq(_usdsToken.owner(), _newOwner);
  }

  function testNewOwnerCanPerformOwnerActions() public {
    vm.prank(_owner);
    _usdsToken.transferOwnership(_newOwner);
    vm.startPrank(_newOwner);
    _usdsToken.acceptOwnership();
    _usdsToken.addMinter(_newMinter);
    vm.stopPrank();
    assertTrue(_usdsToken.minters(_newMinter));
    assertTrue(_usdsToken.minters(_minter));
  }

  function testOnlyOwnerCanSetMinter() public {
    vm.prank(_newOwner);
    vm.expectRevert("Ownable: caller is not the owner");
    _usdsToken.addMinter(_newMinter);
    assertTrue(_usdsToken.minters(_minter));
  }

  function testOwnerCantMint() public {
    vm.prank(_owner);
    vm.expectRevert(OnlyMinterErr);
    _usdsToken.mint(_newMinter, 100);
  }

  function testMinterCanMint() public {
    assertEq(_usdsToken.balanceOf(_newMinter), 0);
    vm.prank(_minter);
    _usdsToken.mint(_newMinter, 100);
    assertEq(_usdsToken.balanceOf(_newMinter), 100);
  }

  function testMinterCantMintToZeroAddress() public {
    vm.prank(_minter);
    vm.expectRevert("ERC20: mint to the zero address");
    _usdsToken.mint(address(0), 100);
  }

  function testNewMinterCanMint() public {
    assertEq(_usdsToken.balanceOf(_newMinter), 0);
    vm.prank(_owner);
    _usdsToken.addMinter(_newMinter);
    vm.prank(_newMinter);
    _usdsToken.mint(_newMinter, 100);
    assertEq(_usdsToken.balanceOf(_newMinter), 100);
  }

  function testAnonymousMinterCantRemove() public {
    vm.prank(_owner);
    vm.expectRevert(MinterNotFoundErr);
    _usdsToken.removeMinter(_newMinter);
    vm.prank(_owner);
    assertFalse(_usdsToken.minters(_newMinter));
  }

  function testAnonymousMinterCantMint() public {
    assertEq(_usdsToken.balanceOf(_newMinter), 0);
    vm.prank(_newMinter);
    vm.expectRevert(OnlyMinterErr);
    _usdsToken.mint(_newMinter, 100);
    assertEq(_usdsToken.balanceOf(_newMinter), 0);
  }

  function testOldOwnerCantTransferOwnership() public {
    vm.prank(_owner);
    _usdsToken.transferOwnership(_newOwner);
    vm.prank(_newOwner);
    _usdsToken.acceptOwnership();
    assertNotEq(_usdsToken.owner(), _owner);
    assertEq(_usdsToken.owner(), _newOwner);
    vm.prank(_owner);
    vm.expectRevert("Ownable: caller is not the owner");
    _usdsToken.transferOwnership(_newMinter);
    assertEq(_usdsToken.owner(), _newOwner);
  }

  function testOldOwnerCantSetMinter() public {
    vm.prank(_owner);
    _usdsToken.transferOwnership(_newOwner);
    vm.prank(_newOwner);
    _usdsToken.acceptOwnership();
    assertNotEq(_usdsToken.owner(), _owner);
    assertEq(_usdsToken.owner(), _newOwner);
    vm.prank(_owner);
    vm.expectRevert("Ownable: caller is not the owner");
    _usdsToken.addMinter(_newMinter);
    assertTrue(_usdsToken.minters(_minter));
  }
}
