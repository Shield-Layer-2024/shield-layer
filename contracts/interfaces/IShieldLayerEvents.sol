// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IShieldLayerEvents {
  /// @notice Event emitted when contract receives ETH
  event Received(address, uint256);

  /// @notice Event emitted when USLT is minted
  event Mint(address minter, address indexed asset, uint256 indexed amount, uint256 indexed usltAmount);

  /// @notice Event emitted when funds are burned
  event Redeem(address redeemer, address indexed asset, uint256 indexed amount, uint256 indexed usltAmount);

  /// @notice Event emitted when custody wallet is added
  event CustodyWalletAdded(address wallet);

  /// @notice Event emitted when a custody wallet is removed
  event CustodyWalletRemoved(address wallet);

  /// @notice Event emitted when a supported asset is added
  event AssetAdded(address indexed asset);

  /// @notice Event emitted when a supported asset is removed
  event AssetRemoved(address indexed asset);

  // @notice Event emitted when a custodian address is added
  event CustodianAddressSet(address indexed custodian);

  // @notice Event emitted when a custodian address is removed
  event CustodianAddressRemoved(address indexed custodian);

  /// @notice Event emitted when assets are moved to custody provider wallet
  event CustodyTransfer(address indexed wallet, address indexed asset, uint256 amount);

  /// @notice Event emitted when USLT is set
  event USLTSet(address indexed USLT);

  /// @notice Event emitted when the max mint per block is changed
  event MaxMintPerBlockChanged(uint256 indexed oldMaxMintPerBlock, uint256 indexed newMaxMintPerBlock);

  /// @notice Event emitted when the max redeem per block is changed
  event MaxBurnPerBlockChanged(uint256 indexed oldMaxBurnPerBlock, uint256 indexed newMaxBurnPerBlock);

  /// @notice Event emitted when a delegated signer is added, enabling it to sign orders on behalf of another address
  event DelegatedSignerAdded(address indexed signer, address indexed delegator);

  /// @notice Event emitted when a delegated signer is removed
  event DelegatedSignerRemoved(address indexed signer, address indexed delegator);
}
