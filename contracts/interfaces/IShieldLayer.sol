// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IShieldLayerEvents.sol";

interface IShieldLayer is IShieldLayerEvents {
  error Duplicate();
  error InvalidAddress();
  error InvalidUSLTAddress();
  error InvalidZeroAddress();
  error InvalidAssetAddress();
  error InvalidAssetRatio();
  error InvalidCustodianAddress();
  error InvalidOrder();
  error InvalidAffirmedAmount();
  error InvalidAmount();
  error InsufficientAsset();
  error InvalidRoute();
  error UnsupportedAsset();
  error NoAssetsProvided();
  error InvalidSignature();
  error InvalidNonce();
  error SignatureExpired();
  error TransferFailed();
  error MaxMintPerBlockExceeded();
  error MaxBurnPerBlockExceeded();

  function mint(address asset, uint256 amount) external;

  function stake(uint256 amount) external;

  function mintAndStake(address asset, uint256 amount) external;

  function redeem(address asset, uint256 amount) external;

  function cooldownShares(uint256 shares) external;

  function unstake() external;

  function rescueTokens(address token, uint256 amount, address to) external;
}
