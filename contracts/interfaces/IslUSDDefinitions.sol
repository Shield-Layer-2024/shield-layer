// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IslUSDDefinitions {
  /// @notice This event is fired when the minter added
  event MinterAdded(address indexed minter);
  /// @notice This event is fired when the minter removed
  event MinterRemoved(address indexed minter);

  /// @notice Zero address not allowed
  error ZeroAddressException();
  /// @notice It's not possible to renounce the ownership
  error CantRenounceOwnership();
  /// @notice Only the minter role can perform an action
  error OnlyMinter();
  /// @notice Minter duplicated
  error MinterDuplicated();
  /// @notice Minter not found
  error MinterNotFound();
}
