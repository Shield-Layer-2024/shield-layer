// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * solhint-disable private-vars-leading-underscore
 */
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IslUSD.sol";
import "./interfaces/IShieldLayerMinting.sol";

/**
 * @title ShieldLayer Minting
 * @notice This contract mints and redeems slUSD in a single, atomic, trustless transaction
 */
contract ShieldLayerMinting is Ownable2Step, IShieldLayerMinting, ReentrancyGuard {
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

  /// @notice slusd stablecoin
  IslUSD public slusd;

  /// @notice Supported assets
  mapping(address => uint256) internal _supportedAssets;

  // @notice custodian addresses
  address public custodianAddress;

  /// @notice holds computable chain id
  uint256 private immutable _chainId;

  /// @notice holds computable domain separator
  bytes32 private immutable _domainSeparator;

  /// @notice user deduplication
  mapping(address => mapping(uint256 => uint256)) private _orderBitmaps;

  /// @notice slUSD minted per block
  mapping(uint256 => uint256) public mintedPerBlock;
  /// @notice slUSD redeemed per block
  mapping(uint256 => uint256) public redeemedPerBlock;

  /// @notice max minted slUSD allowed per block
  uint256 public maxMintPerBlock;
  /// @notice max redeemed slUSD allowed per block
  uint256 public maxRedeemPerBlock;

  /* --------------- MODIFIERS --------------- */

  /// @notice ensure that the already minted slUSD in the actual block plus the amount to be minted is below the maxMintPerBlock var
  /// @param mintAmount The slUSD amount to be minted
  modifier belowMaxMintPerBlock(uint256 mintAmount) {
    if (mintedPerBlock[block.number] + mintAmount > maxMintPerBlock) revert MaxMintPerBlockExceeded();
    _;
  }

  /// @notice ensure that the already redeemed slUSD in the actual block plus the amount to be redeemed is below the maxRedeemPerBlock var
  /// @param redeemAmount The slUSD amount to be redeemed
  modifier belowMaxRedeemPerBlock(uint256 redeemAmount) {
    if (redeemedPerBlock[block.number] + redeemAmount > maxRedeemPerBlock) revert MaxRedeemPerBlockExceeded();
    _;
  }

  /* --------------- CONSTRUCTOR --------------- */

  constructor(IslUSD _slusd, uint256 _maxMintPerBlock, uint256 _maxRedeemPerBlock) {
    if (address(_slusd) == address(0)) revert InvalidslUSDAddress();
    slusd = _slusd;

    // Set the max mint/redeem limits per block
    _setMaxMintPerBlock(_maxMintPerBlock);
    _setMaxRedeemPerBlock(_maxRedeemPerBlock);

    _chainId = block.chainid;
    _domainSeparator = _computeDomainSeparator();

    emit slUSDSet(address(_slusd));
  }

  /* --------------- EXTERNAL --------------- */

  /**
   * @notice Fallback function to receive ether
   */
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /// @notice Mint stablecoins from assets
  function mint(address asset, uint256 amount) external override nonReentrant belowMaxMintPerBlock(amount) {
    // Add to the minted amount in this block
    mintedPerBlock[block.number] += amount;
    _transferCollateralToCustodian(amount, asset, msg.sender);

    uint256 assetRatio = getAssetRatio(asset);
    uint256 slusdAmount = amount * assetRatio / 10000;

    slusd.mint(msg.sender, slusdAmount);
    emit Mint(msg.sender, asset, amount, slusdAmount);
  }

  /// @notice Redeem stablecoins for assets
  function redeem(address asset, uint256 amount) external override nonReentrant belowMaxRedeemPerBlock(amount) {
    // Add to the redeemed amount in this block
    redeemedPerBlock[block.number] += amount;
    slusd.burnFrom(msg.sender, amount);

    uint256 assetRatio = getAssetRatio(asset);
    uint256 assetAmount = amount * 10000 / assetRatio;

    _transferToBeneficiary(msg.sender, asset, assetAmount);
    emit Redeem(msg.sender, asset, assetAmount, amount);
  }

  /// @notice Sets the max mintPerBlock limit
  function setMaxMintPerBlock(uint256 _maxMintPerBlock) external onlyOwner {
    _setMaxMintPerBlock(_maxMintPerBlock);
  }

  /// @notice Sets the max redeemPerBlock limit
  function setMaxRedeemPerBlock(uint256 _maxRedeemPerBlock) external onlyOwner {
    _setMaxRedeemPerBlock(_maxRedeemPerBlock);
  }

  /// @notice Disables the mint and redeem
  function disableMintRedeem() external onlyOwner {
    _setMaxMintPerBlock(0);
    _setMaxRedeemPerBlock(0);
  }

  /* --------------- PUBLIC --------------- */

  /// @notice Checks if an asset is supported.
  function isSupportedAsset(address asset) public view returns (bool) {
    return _supportedAssets[asset] > 0;
  }

  /// @notice Get asset swap ratio
  function getAssetRatio(address asset) public view returns (uint256) {
    if (_supportedAssets[asset] == 0) revert UnsupportedAsset();

    return _supportedAssets[asset];
  }

  /// @notice Adds an asset to the supported assets list.
  function addSupportedAsset(address asset, uint256 ratio) public onlyOwner {
    if (asset == address(0) || asset == address(slusd) || !(_supportedAssets[asset] == 0)) revert InvalidAssetAddress();
    if (ratio == 0) revert InvalidAssetRatio();

    _supportedAssets[asset] = ratio;

    emit AssetAdded(asset);
  }

  /// @notice Removes an asset from the supported assets list
  function removeSupportedAsset(address asset) public onlyOwner {
    if (_supportedAssets[asset] == 0) revert InvalidAssetAddress();

    _supportedAssets[asset] = 0;

    emit AssetRemoved(asset);
  }

  /// @notice Adds an custodian to the supported custodians list.
  function setCustodianAddress(address custodian) public onlyOwner {
    if (custodian == address(0) || custodian == address(slusd) || custodian == custodianAddress) {
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

  /// @notice transfer supported asset to beneficiary address
  function _transferToBeneficiary(address beneficiary, address asset, uint256 amount) internal {
    if (asset == NATIVE_TOKEN) {
      if (address(this).balance < amount) revert InvalidAmount();
      (bool success,) = (beneficiary).call{value: amount}("");
      if (!success) revert TransferFailed();
    } else {
      if (_supportedAssets[asset] == 0) revert UnsupportedAsset();
      IERC20(asset).safeTransfer(beneficiary, amount);
    }
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
  function _setMaxRedeemPerBlock(uint256 _maxRedeemPerBlock) internal {
    uint256 oldMaxRedeemPerBlock = maxRedeemPerBlock;
    maxRedeemPerBlock = _maxRedeemPerBlock;
    emit MaxRedeemPerBlockChanged(oldMaxRedeemPerBlock, maxRedeemPerBlock);
  }

  /// @notice Compute the current domain separator
  /// @return The domain separator for the token
  function _computeDomainSeparator() internal view returns (bytes32) {
    return keccak256(abi.encode(EIP712_DOMAIN, EIP_712_NAME, EIP712_REVISION, block.chainid, address(this)));
  }
}
