// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase  */

import "./utils/ShieldLayerMinting.utils.sol";

contract ShieldLayerMintingCoreTest is ShieldLayerMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function test_mint() public {
    executeMint();
  }

  function test_redeem() public {
    executeRedeem();
    assertEq(stETHToken.balanceOf(address(ShieldLayerMintingContract)), 0, "Mismatch in stETH balance");
    assertEq(stETHToken.balanceOf(beneficiary), _stETHToDeposit, "Mismatch in stETH balance");
    assertEq(slusdToken.balanceOf(beneficiary), 0, "Mismatch in USDs balance");
  }

  function test_redeem_invalidNonce_revert() public {
    // Unset the max redeem per block limit
    vm.prank(owner);
    ShieldLayerMintingContract.setMaxRedeemPerBlock(type(uint256).max);

    (IShieldLayerMinting.Order memory redeemOrder) = redeem_setup(_slusdToMint, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    ShieldLayerMintingContract.redeem(redeemOrder);

    vm.expectRevert(InvalidNonce);
    ShieldLayerMintingContract.redeem(redeemOrder);
  }

  function test_nativeEth_withdraw() public {
    vm.deal(address(ShieldLayerMintingContract), _stETHToDeposit);

    IShieldLayerMinting.Order memory order = IShieldLayerMinting.Order({
      orderType: IShieldLayerMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 8,
      benefactor: benefactor,
      beneficiary: benefactor,
      collateralAsset: address(stETHToken),
      collateralAmount: _stETHToDeposit
    });

    address[] memory targets = new address[](1);
    targets[0] = address(ShieldLayerMintingContract);

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(ShieldLayerMintingContract), _stETHToDeposit);
    vm.stopPrank();

    assertEq(slusdToken.balanceOf(benefactor), 0);

    vm.recordLogs();
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
    vm.getRecordedLogs();

    assertEq(slusdToken.balanceOf(benefactor), _slusdToMint);

    //redeem
    IShieldLayerMinting.Order memory redeemOrder = IShieldLayerMinting.Order({
      orderType: IShieldLayerMinting.OrderType.REDEEM,
      expiry: block.timestamp + 10 minutes,
      nonce: 800,
      benefactor: benefactor,
      beneficiary: benefactor,
      collateralAsset: NATIVE_TOKEN,
      collateralAmount: _stETHToDeposit
    });

    // taker
    vm.startPrank(benefactor);
    slusdToken.approve(address(ShieldLayerMintingContract), _slusdToMint);
    vm.stopPrank();

    vm.startPrank(redeemer);
    ShieldLayerMintingContract.redeem(redeemOrder);

    assertEq(stETHToken.balanceOf(benefactor), 0);
    assertEq(slusdToken.balanceOf(benefactor), 0);
    assertEq(benefactor.balance, _stETHToDeposit);

    vm.stopPrank();
  }

  function test_fuzz_mint_noSlippage(uint256 expectedAmount) public {
    vm.assume(expectedAmount > 0 && expectedAmount < _maxMintPerBlock);

    (IShieldLayerMinting.Order memory order) = mint_setup(expectedAmount, 1, false);

    vm.recordLogs();
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
    vm.getRecordedLogs();
    assertEq(stETHToken.balanceOf(benefactor), 0);
    assertEq(stETHToken.balanceOf(address(ShieldLayerMintingContract)), _stETHToDeposit);
    assertEq(slusdToken.balanceOf(beneficiary), expectedAmount);
  }

  function test_fuzz_multipleInvalid_custodyRatios_revert(uint256 ratio1) public {
    ratio1 = bound(ratio1, 0, UINT256_MAX - 7_000);
    vm.assume(ratio1 != 3_000);

    IShieldLayerMinting.Order memory mintOrder = IShieldLayerMinting.Order({
      orderType: IShieldLayerMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 15,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateralAsset: address(stETHToken),
      collateralAmount: _stETHToDeposit
    });

    address[] memory targets = new address[](2);
    targets[0] = address(ShieldLayerMintingContract);
    targets[1] = owner;

    vm.startPrank(benefactor);
    stETHToken.approve(address(ShieldLayerMintingContract), _stETHToDeposit);
    vm.stopPrank();

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);

    vm.expectRevert(InvalidRoute);
    vm.prank(minter);
    ShieldLayerMintingContract.mint(mintOrder);

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(slusdToken.balanceOf(beneficiary), 0);

    assertEq(stETHToken.balanceOf(address(ShieldLayerMintingContract)), 0);
    assertEq(stETHToken.balanceOf(owner), 0);
  }

  function test_fuzz_singleInvalid_custodyRatio_revert(uint256 ratio1) public {
    vm.assume(ratio1 != 10_000);

    IShieldLayerMinting.Order memory order = IShieldLayerMinting.Order({
      orderType: IShieldLayerMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 16,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateralAsset: address(stETHToken),
      collateralAmount: _stETHToDeposit
    });

    address[] memory targets = new address[](1);
    targets[0] = address(ShieldLayerMintingContract);

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(ShieldLayerMintingContract), _stETHToDeposit);
    vm.stopPrank();

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);

    vm.expectRevert(InvalidRoute);
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(slusdToken.balanceOf(beneficiary), 0);

    assertEq(stETHToken.balanceOf(address(ShieldLayerMintingContract)), 0);
  }

  function test_unsupported_assets_ERC20_revert() public {
    vm.startPrank(owner);
    ShieldLayerMintingContract.removeSupportedAsset(address(stETHToken));
    stETHToken.mint(_stETHToDeposit, benefactor);
    vm.stopPrank();

    IShieldLayerMinting.Order memory order = IShieldLayerMinting.Order({
      orderType: IShieldLayerMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 18,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateralAsset: address(stETHToken),
      collateralAmount: _stETHToDeposit
    });

    address[] memory targets = new address[](1);
    targets[0] = address(ShieldLayerMintingContract);

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(ShieldLayerMintingContract), _stETHToDeposit);
    vm.stopPrank();

    vm.recordLogs();
    vm.expectRevert(UnsupportedAsset);
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
    vm.getRecordedLogs();
  }

  function test_unsupported_assets_ETH_revert() public {
    vm.startPrank(owner);
    vm.deal(benefactor, _stETHToDeposit);
    vm.stopPrank();

    IShieldLayerMinting.Order memory order = IShieldLayerMinting.Order({
      orderType: IShieldLayerMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 19,
      benefactor: benefactor,
      beneficiary: beneficiary,
      collateralAsset: NATIVE_TOKEN,
      collateralAmount: _stETHToDeposit
    });

    address[] memory targets = new address[](1);
    targets[0] = address(ShieldLayerMintingContract);

    // taker
    vm.startPrank(benefactor);
    stETHToken.approve(address(ShieldLayerMintingContract), _stETHToDeposit);
    vm.stopPrank();

    vm.recordLogs();
    vm.expectRevert(UnsupportedAsset);
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
    vm.getRecordedLogs();
  }

  function test_expired_orders_revert() public {
    (IShieldLayerMinting.Order memory order) = mint_setup(_stETHToDeposit, 1, false);

    vm.warp(block.timestamp + 11 minutes);

    vm.recordLogs();
    vm.expectRevert(SignatureExpired);
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
    vm.getRecordedLogs();
  }

  function test_add_and_remove_supported_asset() public {
    address asset = address(20);
    vm.expectEmit(true, false, false, false);
    emit AssetAdded(asset);
    vm.startPrank(owner);
    ShieldLayerMintingContract.addSupportedAsset(asset);
    assertTrue(ShieldLayerMintingContract.isSupportedAsset(asset));

    vm.expectEmit(true, false, false, false);
    emit AssetRemoved(asset);
    ShieldLayerMintingContract.removeSupportedAsset(asset);
    assertFalse(ShieldLayerMintingContract.isSupportedAsset(asset));
  }

  function test_cannot_add_asset_already_supported_revert() public {
    address asset = address(20);
    vm.expectEmit(true, false, false, false);
    emit AssetAdded(asset);
    vm.startPrank(owner);
    ShieldLayerMintingContract.addSupportedAsset(asset);
    assertTrue(ShieldLayerMintingContract.isSupportedAsset(asset));

    vm.expectRevert(InvalidAssetAddress);
    ShieldLayerMintingContract.addSupportedAsset(asset);
  }

  function test_cannot_removeAsset_not_supported_revert() public {
    address asset = address(20);
    assertFalse(ShieldLayerMintingContract.isSupportedAsset(asset));

    vm.prank(owner);
    vm.expectRevert(InvalidAssetAddress);
    ShieldLayerMintingContract.removeSupportedAsset(asset);
  }

  function test_cannotAdd_addressZero_revert() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAssetAddress);
    ShieldLayerMintingContract.addSupportedAsset(address(0));
  }

  function test_cannotAdd_USDs_revert() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAssetAddress);
    ShieldLayerMintingContract.addSupportedAsset(address(slusdToken));
  }

  function test_sending_redeem_order_to_mint_revert() public {
    (IShieldLayerMinting.Order memory order) = redeem_setup(1 ether, 50 ether, 20, false);

    address[] memory targets = new address[](1);
    targets[0] = address(ShieldLayerMintingContract);

    vm.expectRevert(InvalidOrder);
    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
  }

  function test_sending_mint_order_to_redeem_revert() public {
    (IShieldLayerMinting.Order memory order) = mint_setup(50 ether, 20, false);

    vm.expectRevert(InvalidOrder);
    vm.prank(redeemer);
    ShieldLayerMintingContract.redeem(order);
  }

  function test_receive_eth() public {
    assertEq(address(ShieldLayerMintingContract).balance, 0);
    vm.deal(owner, 10_000 ether);
    vm.prank(owner);
    (bool success,) = address(ShieldLayerMintingContract).call{value: 10_000 ether}("");
    assertTrue(success);
    assertEq(address(ShieldLayerMintingContract).balance, 10_000 ether);
  }
}
