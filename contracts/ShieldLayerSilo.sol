// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./SingleAdminAccessControl.sol";

/**
 * @title USLTSilo
 * @notice The Silo allows to store USDe during the stake cooldown process.
 */
contract ShieldLayerSilo is SingleAdminAccessControl {
  using SafeERC20 for IERC20;

  bytes32 private constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(CONTROLLER_ROLE, msg.sender);
  }

  function withdraw(address token, address to, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
    IERC20(token).transfer(to, amount);
  }
}
