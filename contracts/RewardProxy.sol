// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import "./SingleAdminAccessControl.sol";
import "./SLUSD.sol";
import "./USDsV2.sol";
import "./ShieldLayer.sol";

/**
 * @title USDsV2
 * @notice The USDsV2 contract allows users to stake USDe tokens and earn a portion of protocol LST and perpetual yield that is allocated
 * to stakers by the Ethena DAO governance voted yield distribution algorithm.  The algorithm seeks to balance the stability of the protocol by funding
 * the protocol's insurance fund, DAO activities, and rewarding stakers with a portion of the protocol's yield.
 * @dev If cooldown duration is set to zero, the USDsV2 behavior changes to follow ERC4626 standard and disables cooldownShares and cooldownAssets methods. If cooldown duration is greater than zero, the ERC4626 withdrawal and redeem functions are disabled, breaking the ERC4626 standard, and enabling the cooldownShares and the cooldownAssets functions.
 */
contract RewardProxy is SingleAdminAccessControl {
  using SafeERC20 for IERC20;

  error InsufficientBalance();

  SLUSD public slusd;
  USDsV2 public usds;
  ShieldLayer public shieldlayer;

  bytes32 internal constant REWARDER_ROLE = keccak256("REWARDER_ROLE");

  constructor(SLUSD _slusd, USDsV2 _usds, ShieldLayer _shieldlayer) {
    slusd = _slusd;
    usds = _usds;
    shieldlayer = _shieldlayer;

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function transferInRewards(IERC20 asset, uint256 amount) external onlyRole(REWARDER_ROLE) {
    if (asset.balanceOf(msg.sender) < amount) revert InsufficientBalance();

    uint256 slusdAmount = shieldlayer.previewMint(address(asset), amount);
    asset.safeTransferFrom(msg.sender, shieldlayer.custodianAddress(), amount);
    slusd.mint(address(this), slusdAmount);
    slusd.approve(address(usds), slusdAmount);
    usds.transferInRewards(slusdAmount);
  }

  function rescueTokens(address token, uint256 amount, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC20(token).safeTransfer(to, amount);
  }
}
