// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IShieldLayerMintingEvents.sol";

interface IShieldLayerMinting is IShieldLayerMintingEvents {
  enum Role {
    Minter,
    Redeemer
  }

  struct Order {
    address asset;
    uint256 amount;
  }

  error Duplicate();
  error InvalidAddress();
  error InvalidslUSDAddress();
  error InvalidZeroAddress();
  error InvalidAssetAddress();
  error InvalidAssetRatio();
  error InvalidCustodianAddress();
  error InvalidOrder();
  error InvalidAffirmedAmount();
  error InvalidAmount();
  error InvalidRoute();
  error UnsupportedAsset();
  error NoAssetsProvided();
  error InvalidSignature();
  error InvalidNonce();
  error SignatureExpired();
  error TransferFailed();
  error MaxMintPerBlockExceeded();
  error MaxRedeemPerBlockExceeded();

  function mint(address asset, uint256 amount) external;

  function redeem(address asset, uint256 amount) external;
}
