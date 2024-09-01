// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IShieldLayerMintingEvents.sol";

interface IShieldLayerMinting is IShieldLayerMintingEvents {
  enum Role {
    Minter,
    Redeemer
  }

  enum OrderType {
    MINT,
    REDEEM
  }

  enum SignatureType {
    EIP712
  }

  struct Signature {
    SignatureType signatureType;
    bytes signatureBytes;
  }

  struct Order {
    OrderType orderType;
    uint256 expiry;
    uint256 nonce;
    address benefactor;
    address beneficiary;
    address collateralAsset;
    uint256 collateralAmount;
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

  function hashOrder(Order calldata order) external view returns (bytes32);

  function mint(Order calldata order) external;

  function redeem(Order calldata order) external;
}
