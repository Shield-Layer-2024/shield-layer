// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./SingleAdminAccessControl.sol";

/**
 * @title USLT
 * @notice Stable Coin Contract
 * @dev Only a single approved minter can mint new tokens
 */
contract USLT is ERC20, ERC20Permit, ERC20Burnable, SingleAdminAccessControl {
  using SafeERC20 for IERC20;

  /* ------------- ROLES ------------- */
  bytes32 internal constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

  constructor() ERC20("USLT", "USLT") ERC20Permit("USLT") {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function mint(address to, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
    _mint(to, amount);
  }

  function rescueTokens(address token, uint256 amount, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC20(token).safeTransfer(to, amount);
  }
}
