// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/* solhint-disable func-name-mixedcase  */

import "forge-std/console.sol";
import "./MintingBaseSetup.sol";

// These functions are reused across multiple files
contract ShieldLayerMintingUtils is MintingBaseSetup {
  function maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    // This amount is always greater than the allowed max mint per block
    vm.assume(excessiveMintAmount > ShieldLayerMintingContract.maxMintPerBlock());
    (IShieldLayerMinting.Order memory order) = mint_setup(_stETHToDeposit, 1, false);

    vm.prank(minter);
    vm.expectRevert(MaxMintPerBlockExceeded);
    ShieldLayerMintingContract.mint(order);

    assertEq(slusdToken.balanceOf(beneficiary), 0, "The beneficiary balance should be 0");
    assertEq(
      stETHToken.balanceOf(address(ShieldLayerMintingContract)), 0, "The ethena minting stETH balance should be 0"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in stETH balance");
  }

  function maxRedeem_perBlock_exceeded_revert(uint256 excessiveRedeemAmount) public {
    // Set the max mint per block to the same value as the max redeem in order to get to the redeem
    vm.prank(owner);
    ShieldLayerMintingContract.setMaxMintPerBlock(excessiveRedeemAmount);

    (IShieldLayerMinting.Order memory redeemOrder) = redeem_setup(excessiveRedeemAmount, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    vm.expectRevert(MaxRedeemPerBlockExceeded);
    ShieldLayerMintingContract.redeem(redeemOrder);

    assertEq(stETHToken.balanceOf(address(ShieldLayerMintingContract)), _stETHToDeposit, "Mismatch in stETH balance");
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in stETH balance");
    assertEq(slusdToken.balanceOf(beneficiary), excessiveRedeemAmount, "Mismatch in USDe balance");

    vm.stopPrank();
  }

  function executeMint() public {
    (IShieldLayerMinting.Order memory order) = mint_setup(_slusdToMint, 1, false);

    vm.prank(minter);
    ShieldLayerMintingContract.mint(order);
  }

  function executeRedeem() public {
    (IShieldLayerMinting.Order memory redeemOrder) = redeem_setup(_slusdToMint, _stETHToDeposit, 1, false);
    vm.prank(redeemer);
    ShieldLayerMintingContract.redeem(redeemOrder);
  }
}
