// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import "./IstUSLT.sol";

struct UserCooldown {
  uint104 cooldownEnd;
  uint256 underlyingAmount;
}

interface IstUSLTCooldown is IstUSLT {
  // Events //
  /// @notice Event emitted when cooldown duration updates
  event CooldownDurationUpdated(uint24 previousDuration, uint24 newDuration);
  /// @notice Event emitted when the silo address updates
  event SiloUpdated(address previousSilo, address newSilo);

  // Errors //
  /// @notice Error emitted when the silo address is zero
  error InvalidSiloAddress();
  /// @notice Error emitted when the shares amount to redeem is greater than the shares balance of the owner
  error ExcessiveRedeemAmount();
  /// @notice Error emitted when the shares amount to withdraw is greater than the shares balance of the owner
  error ExcessiveWithdrawAmount();
  /// @notice Error emitted when cooldown value is invalid
  error InvalidCooldown();

  function cooldownAssets(uint256 assets, address owner) external returns (uint256 shares);

  function cooldownShares(uint256 shares, address owner) external returns (uint256 assets);

  function unstake(address receiver) external;

  function setCooldownDuration(uint24 duration) external;
}
