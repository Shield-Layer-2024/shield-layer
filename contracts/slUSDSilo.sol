// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IslUSDSiloDefinitions.sol";

/**
 * @title slUSDSilo
 * @notice The Silo allows to store USDe during the stake cooldown process.
 */
contract slUSDSilo is IslUSDSiloDefinitions {
  using SafeERC20 for IERC20;

  address immutable STAKING_VAULT;
  IERC20 immutable slUSD;

  constructor(address stakingVault, address slusd) {
    STAKING_VAULT = stakingVault;
    slUSD = IERC20(slusd);
  }

  modifier onlyStakingVault() {
    if (msg.sender != STAKING_VAULT) revert OnlyStakingVault();
    _;
  }

  function withdraw(address to, uint256 amount) external onlyStakingVault {
    slUSD.transfer(to, amount);
  }
}
