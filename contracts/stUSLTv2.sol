// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import "./interfaces/IstUSLTCooldown.sol";
import "./ShieldLayerSilo.sol";
import "./stUSLT.sol";

/**
 * @title stUSLTv2
 * @dev If cooldown duration is set to zero, the stUSLTv2 behavior changes to follow ERC4626 standard and disables cooldownShares and cooldownAssets methods. If cooldown duration is greater than zero, the ERC4626 withdrawal and redeem functions are disabled, breaking the ERC4626 standard, and enabling the cooldownShares and the cooldownAssets functions.
 */
contract stUSLTv2 is IstUSLTCooldown, stUSLT {
  using SafeERC20 for IERC20;

  mapping(address => UserCooldown) public cooldowns;

  ShieldLayerSilo public silo;

  uint24 internal constant MAX_COOLDOWN_DURATION = 90 days;

  uint24 public cooldownDuration;

  /// @notice ensure cooldownDuration is zero
  modifier ensureCooldownOff() {
    if (cooldownDuration != 0) revert OperationNotAllowed();
    _;
  }

  /// @notice ensure cooldownDuration is gt 0
  modifier ensureCooldownOn() {
    if (cooldownDuration == 0) revert OperationNotAllowed();
    _;
  }

  /// @notice Constructor for stUSLTv2 contract.
  /// @param _asset The address of the USDe token.
  constructor(IERC20 _asset, ShieldLayerSilo _silo) stUSLT(_asset) {
    silo = _silo;
  }

  /* ------------- EXTERNAL ------------- */

  /**
   * @dev See {IERC4626-withdraw}.
   */
  function withdraw(uint256 assets, address receiver, address owner)
    public
    virtual
    override(IERC4626, ERC4626)
    ensureCooldownOff
    returns (uint256)
  {
    return super.withdraw(assets, receiver, owner);
  }

  /**
   * @dev See {IERC4626-redeem}.
   */
  function redeem(uint256 shares, address receiver, address owner)
    public
    virtual
    override(IERC4626, ERC4626)
    ensureCooldownOff
    returns (uint256)
  {
    return super.redeem(shares, receiver, owner);
  }

  /// @notice Claim the staking amount after the cooldown has finished. The address can only retire the full amount of assets.
  /// @dev unstake can be called after cooldown have been set to 0, to let accounts to be able to claim remaining assets locked at Silo
  /// @param receiver Address to send the assets by the staker
  function unstake(address receiver) external onlyRole(CONTROLLER_ROLE) {
    UserCooldown storage userCooldown = cooldowns[receiver];
    uint256 assets = userCooldown.underlyingAmount;

    if (block.timestamp >= userCooldown.cooldownEnd) {
      userCooldown.cooldownEnd = 0;
      userCooldown.underlyingAmount = 0;

      silo.withdraw(asset(), receiver, assets);
    } else {
      revert InvalidCooldown();
    }
  }

  /// @notice redeem assets and starts a cooldown to claim the converted underlying asset
  /// @param assets assets to redeem
  /// @param owner address to redeem and start cooldown, owner must allowed caller to perform this action
  function cooldownAssets(uint256 assets, address owner)
    external
    ensureCooldownOn
    onlyRole(CONTROLLER_ROLE)
    returns (uint256)
  {
    if (assets > maxWithdraw(owner)) revert ExcessiveWithdrawAmount();

    uint256 shares = previewWithdraw(assets);

    cooldowns[owner].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
    cooldowns[owner].underlyingAmount += assets;

    _withdraw(_msgSender(), address(silo), owner, assets, shares);

    return shares;
  }

  /// @notice redeem shares into assets and starts a cooldown to claim the converted underlying asset
  /// @param shares shares to redeem
  /// @param owner address to redeem and start cooldown, owner must allowed caller to perform this action
  function cooldownShares(uint256 shares, address owner)
    external
    ensureCooldownOn
    onlyRole(CONTROLLER_ROLE)
    returns (uint256)
  {
    if (shares > maxRedeem(owner)) revert ExcessiveRedeemAmount();

    uint256 assets = previewRedeem(shares);

    cooldowns[owner].cooldownEnd = uint104(block.timestamp) + cooldownDuration;
    cooldowns[owner].underlyingAmount += assets;

    _withdraw(_msgSender(), address(silo), owner, assets, shares);

    return assets;
  }

  /// @notice Set cooldown duration. If cooldown duration is set to zero, the stUSLTv2 behavior changes to follow ERC4626 standard and disables cooldownShares and cooldownAssets methods. If cooldown duration is greater than zero, the ERC4626 withdrawal and redeem functions are disabled, breaking the ERC4626 standard, and enabling the cooldownShares and the cooldownAssets functions.
  /// @param duration Duration of the cooldown
  function setCooldownDuration(uint24 duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (duration > MAX_COOLDOWN_DURATION) {
      revert InvalidCooldown();
    }

    uint24 previousDuration = cooldownDuration;
    cooldownDuration = duration;
    emit CooldownDurationUpdated(previousDuration, cooldownDuration);
  }
}
