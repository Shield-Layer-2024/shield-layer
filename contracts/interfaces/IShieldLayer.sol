// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IShieldLayerEvents.sol";

interface IShieldLayer is IShieldLayerEvents {
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
  error MaxBurnPerBlockExceeded();

  function mint(address asset, uint256 amount) external;

  function deposit(uint256 amount) external;

  function mintAndDeposit(address asset, uint256 amount) external;

  function burn(address asset, uint256 amount) external;

  function redeem(uint256 shares) external;

  // function redeemAndBurn(uint256 shares, address asset) external;

  function rescueTokens(address token, uint256 amount, address to) external;
}
