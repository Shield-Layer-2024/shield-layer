// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IslUSDDefinitions.sol";

/**
 * @title slUSD
 * @notice Stable Coin Contract
 * @dev Only a single approved minter can mint new tokens
 */
contract slUSD is Ownable2Step, ERC20Burnable, ERC20Permit, IslUSDDefinitions {
  mapping(address => bool) public minters;

  constructor(address admin) ERC20("slUSD", "slUSD") ERC20Permit("slUSD") {
    if (admin == address(0)) revert ZeroAddressException();

    _transferOwnership(admin);
  }

  function addMinter(address minter) external onlyOwner {
    if (minters[minter]) revert MinterDuplicated();

    emit MinterAdded(minter);
    minters[minter] = true;
  }

  function removeMinter(address minter) external onlyOwner {
    if (!minters[minter]) revert MinterNotFound();

    emit MinterRemoved(minter);
    delete minters[minter];
  }

  function mint(address to, uint256 amount) external {
    if (!minters[msg.sender]) revert OnlyMinter();

    _mint(to, amount);
  }

  function renounceOwnership() public view override onlyOwner {
    revert CantRenounceOwnership();
  }

  function decimals() public pure override returns (uint8) {
    return 6;
  }
}
