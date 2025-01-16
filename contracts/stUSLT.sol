// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * solhint-disable private-vars-leading-underscore
 */
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./SingleAdminAccessControl.sol";
import "./interfaces/IstUSLT.sol";

/**
 * @title stUSLT
 * @notice The stUSLT contract allows users to stake stUSLT tokens and earn a portion of protocol LST and perpetual yield that is allocated
 * to stakers by the Ethena DAO governance voted yield distribution algorithm.  The algorithm seeks to balance the stability of the protocol by funding
 * the protocol's insurance fund, DAO activities, and rewarding stakers with a portion of the protocol's yield.
 */
contract stUSLT is SingleAdminAccessControl, ReentrancyGuard, ERC20Permit, ERC4626, IstUSLT {
  using SafeERC20 for IERC20;

  /* ------------- ROLES ------------- */
  bytes32 internal constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
  bytes32 internal constant REWARDER_ROLE = keccak256("REWARDER_ROLE");

  /* ------------- CONSTANTS ------------- */
  /// @notice The vesting period of lastDistributionAmount over which it increasingly becomes available to stakers
  uint256 private constant VESTING_PERIOD = 8 hours;
  /// @notice Minimum non-zero shares amount to prevent donation attack
  uint256 private constant MIN_SHARES = 1 ether;

  /* ------------- STATE VARIABLES ------------- */

  /// @notice The amount of the last asset distribution from the controller contract into this
  /// contract + any unvested remainder at that time
  uint256 public vestingAmount;

  /// @notice The timestamp of the last asset distribution from the controller contract into this contract
  uint256 public lastDistributionTimestamp;

  /* ------------- MODIFIERS ------------- */

  /// @notice ensure input amount nonzero
  modifier notZero(uint256 amount) {
    if (amount == 0) revert InvalidAmount();
    _;
  }

  /* ------------- CONSTRUCTOR ------------- */

  /**
   * @notice Constructor for stUSLT contract.
   * @param _asset The address of the stUSLT token.
   */
  constructor(IERC20 _asset) ERC20("stUSLT", "stUSLT") ERC4626(_asset) ERC20Permit("stUSLT") {
    if (address(_asset) == address(0)) revert InvalidZeroAddress();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /* ------------- EXTERNAL ------------- */

  /**
   * @notice Allows the owner to transfer rewards from the controller contract into this contract.
   * @param amount The amount of rewards to transfer.
   */
  function transferInRewards(uint256 amount) external nonReentrant onlyRole(REWARDER_ROLE) notZero(amount) {
    if (getUnvestedAmount() > 0) revert StillVesting();
    lastDistributionTimestamp = block.timestamp;
    IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);

    emit RewardsReceived(amount, amount);
  }

  /**
   * @notice Allows the owner to rescue tokens accidentally sent to the contract.
   * Note that the owner cannot rescue stUSLT tokens because they functionally sit here
   * and belong to stakers but can rescue staked stUSLT as they should never actually
   * sit in this contract and a staker may well transfer them here by accident.
   * @param token The token to be rescued.
   * @param amount The amount of tokens to be rescued.
   * @param to Where to send rescued tokens
   */
  function rescueTokens(address token, uint256 amount, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (address(token) == asset()) revert InvalidToken();
    IERC20(token).safeTransfer(to, amount);
  }

  /* ------------- PUBLIC ------------- */

  function deposit(uint256 assets, address caller) public virtual override(IERC4626, ERC4626) returns (uint256) {
    require(assets <= maxDeposit(caller), "ERC4626: deposit more than max");

    uint256 shares = previewDeposit(assets);
    _deposit(caller, assets, shares);

    return shares;
  }

  /**
   * @notice Returns the amount of stUSLT tokens that are vested in the contract.
   */
  function totalAssets() public view override(IERC4626, ERC4626) returns (uint256) {
    return IERC20(asset()).balanceOf(address(this)) - getUnvestedAmount();
  }

  /**
   * @notice Returns the amount of stUSLT tokens that are unvested in the contract.
   */
  function getUnvestedAmount() public view returns (uint256) {
    uint256 timeSinceLastDistribution = block.timestamp - lastDistributionTimestamp;

    if (timeSinceLastDistribution >= VESTING_PERIOD) {
      return 0;
    }

    return ((VESTING_PERIOD - timeSinceLastDistribution) * vestingAmount) / VESTING_PERIOD;
  }

  /// @dev Necessary because both ERC20 (from ERC20Permit) and ERC4626 declare decimals()
  function decimals() public pure override(IERC20Metadata, ERC4626, ERC20) returns (uint8) {
    return 18;
  }

  /* ------------- INTERNAL ------------- */

  /**
   * @dev Deposit/mint common workflow.
   * @param caller sender of assets
   * @param assets assets to deposit
   * @param shares shares to mint
   */
  function _deposit(address caller, uint256 assets, uint256 shares)
    internal
    nonReentrant
    notZero(assets)
    notZero(shares)
    onlyRole(CONTROLLER_ROLE)
  {
    super._deposit(caller, caller, assets, shares);
  }

  /**
   * @dev Withdraw/redeem common workflow.
   * @param caller tx sender
   * @param receiver where to send assets
   * @param _owner where to burn shares from
   * @param assets asset amount to transfer out
   * @param shares shares to burn
   */
  function _withdraw(address caller, address receiver, address _owner, uint256 assets, uint256 shares)
    internal
    override
    nonReentrant
    notZero(assets)
    notZero(shares)
    onlyRole(CONTROLLER_ROLE)
  {
    super._withdraw(caller, receiver, _owner, assets, shares);
  }

  /**
   * @dev Remove renounce role access from AccessControl, to prevent users to resign roles.
   */
  function renounceRole(bytes32, address) public virtual override {
    revert OperationNotAllowed();
  }
}
