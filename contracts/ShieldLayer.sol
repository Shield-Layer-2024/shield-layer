// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * solhint-disable private-vars-leading-underscore
 */
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IShieldLayer.sol";
import "./SingleAdminAccessControl.sol";
import "./USLT.sol";
import "./stUSLTv2.sol";

/**
 * @title ShieldLayer
 * @notice This contract mints and redeems USLT in a single, atomic, trustless transaction
 */
contract ShieldLayer is SingleAdminAccessControl, IShieldLayer, ReentrancyGuard {
  using SafeERC20 for IERC20;

  /* --------------- CONSTANTS --------------- */

  /// @notice EIP712 domain
  bytes32 private constant EIP712_DOMAIN =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice EIP712 domain hash
  bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(EIP712_DOMAIN));

  /// @notice address denoting native ether
  address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice EIP712 name
  bytes32 private constant EIP_712_NAME = keccak256("ShieldLayerMinting");

  /// @notice holds EIP712 revision
  bytes32 private constant EIP712_REVISION = keccak256("1");

  /* --------------- STATE VARIABLES --------------- */

  /// @notice uslt stablecoin
  USLT public uslt;
  stUSLTv2 public stuslt;

  /// @notice Supported assets
  mapping(address => uint256) internal _supportedAssets;

  // @notice custodian addresses
  address public custodianAddress;

  /// @notice holds computable chain id
  uint256 private immutable _chainId;

  /// @notice holds computable domain separator
  bytes32 private immutable _domainSeparator;

  /// @notice USLT minted per block
  mapping(uint256 => uint256) public mintedPerBlock;
  /// @notice max minted USLT allowed per block
  uint256 public maxMintPerBlock;
  /// @notice USLT burned per block
  mapping(uint256 => uint256) public burnedPerBlock;
  /// @notice max burned USLT allowed per block
  uint256 public maxBurnPerBlock;

  /* --------------- MODIFIERS --------------- */

  /// @notice cannot mint before custodian is not set
  modifier ensureCustodian() {
    if (custodianAddress == address(0)) revert InvalidCustodianAddress();
    _;
  }

  /// @notice cannot mint using unsupported asset or native ETH even if it is supported for redemptions
  modifier ensureAssetSupported(address asset) {
    if (_supportedAssets[asset] == 0 || asset == NATIVE_TOKEN) revert UnsupportedAsset();
    _;
  }

  /// @notice ensure that the already minted USLT in the actual block plus the amount to be minted is below the maxMintPerBlock var
  /// @param mintAmount The USLT amount to be minted
  modifier belowMaxMintPerBlock(uint256 mintAmount) {
    if (mintedPerBlock[block.number] + mintAmount > maxMintPerBlock) revert MaxMintPerBlockExceeded();
    _;
  }

  /// @notice ensure that the already burned USLT in the actual block plus the amount to be burned is below the maxBurnPerBlock var
  /// @param redeemAmount The USLT amount to be burned
  modifier belowMaxBurnPerBlock(uint256 redeemAmount) {
    if (burnedPerBlock[block.number] + redeemAmount > maxBurnPerBlock) revert MaxBurnPerBlockExceeded();
    _;
  }

  /* --------------- CONSTRUCTOR --------------- */

  constructor(USLT _uslt, stUSLTv2 _stuslt, uint256 _maxMintPerBlock, uint256 _maxBurnPerBlock) {
    if (address(_uslt) == address(0) || address(_stuslt) == address(0)) revert InvalidUSLTAddress();
    uslt = _uslt;
    stuslt = _stuslt;

    // Set the max mint/redeem limits per block
    _setMaxMintPerBlock(_maxMintPerBlock);
    _setMaxBurnPerBlock(_maxBurnPerBlock);

    _chainId = block.chainid;
    _domainSeparator = _computeDomainSeparator();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    emit USLTSet(address(_uslt));
  }

  /* --------------- EXTERNAL --------------- */
  /// @notice Mint stablecoins from assets
  function mint(address asset, uint256 amount) external nonReentrant belowMaxMintPerBlock(amount) {
    _mint(asset, amount);
  }

  function stake(uint256 amount) external {
    stuslt.deposit(amount, msg.sender);
  }

  function mintAndStake(address asset, uint256 amount) external {
    uint256 usltAmount = _mint(asset, amount);
    uslt.approve(address(stuslt), usltAmount);
    stuslt.deposit(usltAmount, msg.sender);
  }

  /// @notice Redeem stablecoins for assets
  function redeem(address asset, uint256 amount) external nonReentrant belowMaxBurnPerBlock(amount) {
    uint256 assetRatio = getAssetRatio(asset);
    uint256 assetAmount = amount / assetRatio;

    if (IERC20(asset).balanceOf(address(this)) < assetAmount) revert InsufficientAsset();

    // Add to the burned amount in this block
    burnedPerBlock[block.number] += amount;
    uslt.burnFrom(msg.sender, amount);

    _transferToBeneficiary(msg.sender, asset, assetAmount);
    emit Redeem(msg.sender, asset, assetAmount, amount);
  }

  function unstake() external {
    stuslt.unstake(msg.sender);
  }

  function cooldownShares(uint256 shares) external {
    stuslt.cooldownShares(shares, msg.sender);
  }

  function rescueTokens(address token, uint256 amount, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @notice Sets the max mintPerBlock limit
  function setMaxMintPerBlock(uint256 _maxMintPerBlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setMaxMintPerBlock(_maxMintPerBlock);
  }

  /// @notice Sets the max redeemPerBlock limit
  function setMaxBurnPerBlock(uint256 _maxBurnPerBlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setMaxBurnPerBlock(_maxBurnPerBlock);
  }

  /// @notice Disables the mint and redeem
  function disableMintBurn() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setMaxMintPerBlock(0);
    _setMaxBurnPerBlock(0);
  }

  /* --------------- PUBLIC --------------- */

  /// @notice Checks if an asset is supported.
  function isSupportedAsset(address asset) public view returns (bool) {
    return _supportedAssets[asset] > 0;
  }

  /// @notice Get asset swap ratio
  function getAssetRatio(address asset) public view ensureAssetSupported(asset) returns (uint256) {
    return _supportedAssets[asset];
  }

  function previewMint(address asset, uint256 amount) public view ensureAssetSupported(asset) returns (uint256) {
    uint256 assetRatio = getAssetRatio(asset);
    return amount * assetRatio;
  }

  /// @notice Adds an asset to the supported assets list.
  function addSupportedAsset(address asset, uint256 ratio) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (asset == address(0) || asset == address(uslt)) revert InvalidAssetAddress();
    if (ratio == 0) revert InvalidAssetRatio();

    _supportedAssets[asset] = ratio;

    emit AssetAdded(asset);
  }

  /// @notice Removes an asset from the supported assets list
  function removeSupportedAsset(address asset) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_supportedAssets[asset] == 0) revert InvalidAssetAddress();

    _supportedAssets[asset] = 0;

    emit AssetRemoved(asset);
  }

  /// @notice Adds an custodian to the supported custodians list.
  function setCustodianAddress(address custodian) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (custodian == address(0) || custodian == address(uslt) || custodian == custodianAddress) {
      revert InvalidCustodianAddress();
    }
    custodianAddress = custodian;
    emit CustodianAddressSet(custodian);
  }

  /// @notice Get the domain separator for the token
  /// @dev Return cached value if chainId matches cache, otherwise recomputes separator, to prevent replay attack across forks
  /// @return The domain separator of the token at current chain
  function getDomainSeparator() public view returns (bytes32) {
    if (block.chainid == _chainId) {
      return _domainSeparator;
    }
    return _computeDomainSeparator();
  }

  /* --------------- PRIVATE --------------- */

  /* --------------- INTERNAL --------------- */

  function _mint(address asset, uint256 amount) internal returns (uint256) {
    // Add to the minted amount in this block
    mintedPerBlock[block.number] += amount;
    _transferCollateralToCustodian(amount, asset, msg.sender);

    uint256 usltAmount = previewMint(asset, amount);

    uslt.mint(msg.sender, usltAmount);
    emit Mint(msg.sender, asset, amount, usltAmount);

    return usltAmount;
  }

  /// @notice transfer supported asset to beneficiary address
  function _transferToBeneficiary(address beneficiary, address asset, uint256 amount) internal {
    // FIXME
    // if (asset == NATIVE_TOKEN) {
    //   if (address(this).balance < amount) revert InvalidAmount();
    //   (bool success,) = (beneficiary).call{value: amount}("");
    //   if (!success) revert TransferFailed();
    // } else {
    //   if (_supportedAssets[asset] == 0) revert UnsupportedAsset();
    //   IERC20(asset).safeTransfer(beneficiary, amount);
    // }

    if (_supportedAssets[asset] == 0) revert UnsupportedAsset();
    IERC20(asset).safeTransfer(beneficiary, amount);
  }

  /// @notice transfer supported asset to array of custody addresses per defined ratio
  function _transferCollateralToCustodian(uint256 amount, address asset, address from) internal {
    // cannot mint before custodian is not set
    if (custodianAddress == address(0)) revert InvalidCustodianAddress();
    // cannot mint using unsupported asset or native ETH even if it is supported for redemptions
    if (_supportedAssets[asset] == 0 || asset == NATIVE_TOKEN) revert UnsupportedAsset();

    IERC20 token = IERC20(asset);
    token.safeTransferFrom(from, custodianAddress, amount);
  }

  /// @notice Sets the max mintPerBlock limit
  function _setMaxMintPerBlock(uint256 _maxMintPerBlock) internal {
    uint256 oldMaxMintPerBlock = maxMintPerBlock;
    maxMintPerBlock = _maxMintPerBlock;
    emit MaxMintPerBlockChanged(oldMaxMintPerBlock, maxMintPerBlock);
  }

  /// @notice Sets the max redeemPerBlock limit
  function _setMaxBurnPerBlock(uint256 _maxBurnPerBlock) internal {
    uint256 oldMaxBurnPerBlock = maxBurnPerBlock;
    maxBurnPerBlock = _maxBurnPerBlock;
    emit MaxBurnPerBlockChanged(oldMaxBurnPerBlock, maxBurnPerBlock);
  }

  /// @notice Compute the current domain separator
  /// @return The domain separator for the token
  function _computeDomainSeparator() internal view returns (bytes32) {
    return keccak256(abi.encode(EIP712_DOMAIN, EIP_712_NAME, EIP712_REVISION, block.chainid, address(this)));
  }
}
