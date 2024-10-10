// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockUSDT is ERC20, ERC20Permit {
  uint8 private __decimals;

  constructor() ERC20("USDT", "USDT") ERC20Permit("USDT") {
    __decimals = 6;
    require(msg.sender != address(0), "Zero address not valid");

    _mint(msg.sender, 100000000 * (10 ** __decimals));
  }

  function decimals() public view override returns (uint8) {
    return __decimals;
  }

  function mint(uint256 amount) external {
    _mint(msg.sender, amount);
  }

  function mint(uint256 amount, address receiver) external {
    _mint(receiver, amount);
  }
}
