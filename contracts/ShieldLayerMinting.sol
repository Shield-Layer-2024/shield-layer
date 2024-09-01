// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * solhint-disable private-vars-leading-underscore
 */
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IslUSD.sol";
import "./interfaces/IShieldLayerMinting.sol";

/**
 * @title ShieldLayer Minting
 * @notice This contract mints and redeems slUSD in a single, atomic, trustless transaction
 */
contract ShieldLayerMinting is Ownable2Step, IShieldLayerMinting, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /* --------------- CONSTANTS --------------- */

  /// @notice EIP712 domain
  bytes32 private constant EIP712_DOMAIN =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice route type
  bytes32 private constant ROUTE_TYPE = keccak256("Route(address[] addresses,uint256[] ratios)");

  /// @notice order type
  bytes32 private constant orderType = keccak256(
    "Order(uint8 orderType,uint256 expiry,uint256 nonce,address benefactor,address beneficiary,address collateralAsset,uint256 collateralAmount)"
  );

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
  EnumerableSet.AddressSet internal _supportedAssets;

  mapping(address => uint256) private _assetRatios;

  // @notice custodian addresses
  address internal _custodianAddress;

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

  /// @notice For smart contracts to delegate signing to EOA address
  mapping(address => mapping(address => bool)) public delegatedSigner;

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

  constructor(
    IslUSD _slusd,
    address[] memory _assets,
    address _custodian,
    address _admin,
    uint256 _maxMintPerBlock,
    uint256 _maxRedeemPerBlock
  ) {
    if (address(_slusd) == address(0)) revert InvalidslUSDAddress();
    if (_assets.length == 0) revert NoAssetsProvided();
    if (_admin == address(0)) revert InvalidZeroAddress();
    slusd = _slusd;

    for (uint256 i = 0; i < _assets.length; i++) {
      addSupportedAsset(_assets[i]);
    }

    setCustodianAddress(_custodian);

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

  /**
   * @notice Mint stablecoins from assets
   * @param order struct containing order details and confirmation from server
   */
  function mint(Order calldata order) external override nonReentrant belowMaxMintPerBlock(order.collateralAmount) {
    if (order.orderType != OrderType.MINT) revert InvalidOrder();

    // Add to the minted amount in this block
    mintedPerBlock[block.number] += order.collateralAmount;
    _transferCollateralToCustodian(order.collateralAmount, order.collateralAsset, order.beneficiary);

    uint256 assetRatio = getAssetRatio(order.collateralAsset);

    slusd.mint(order.beneficiary, order.collateralAmount / 100 * assetRatio);
    emit Mint(
      msg.sender,
      order.benefactor,
      order.beneficiary,
      order.collateralAsset,
      order.collateralAmount,
      order.collateralAmount / 100 * assetRatio
    );
  }

  /**
   * @notice Redeem stablecoins for assets
   * @param order struct containing order details and confirmation from server
   */
  function redeem(Order calldata order) external override nonReentrant belowMaxRedeemPerBlock(order.collateralAmount) {
    if (order.orderType != OrderType.REDEEM) revert InvalidOrder();

    // Add to the redeemed amount in this block
    redeemedPerBlock[block.number] += order.collateralAmount;
    slusd.burnFrom(order.benefactor, order.collateralAmount);
    _transferToBeneficiary(order.beneficiary, order.collateralAsset, order.collateralAmount);
    emit Redeem(
      msg.sender,
      order.benefactor,
      order.beneficiary,
      order.collateralAsset,
      order.collateralAmount,
      order.collateralAmount
    );
  }

  /**
   * @notice Get Asset swap ratio
   * @param asset struct containing order details and confirmation from server
   */
  function getAssetRatio(address asset) public view returns (uint256) {
    uint256 ratio = _assetRatios[asset];
    return ratio > 0 ? ratio : (_supportedAssets.contains(asset) ? 100 : 0);
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

  /// @notice Removes an asset from the supported assets list
  function removeSupportedAsset(address asset) external onlyOwner {
    if (!_supportedAssets.remove(asset)) revert InvalidAssetAddress();
    emit AssetRemoved(asset);
  }

  /// @notice Checks if an asset is supported.
  function isSupportedAsset(address asset) external view returns (bool) {
    return _supportedAssets.contains(asset);
  }

  /* --------------- PUBLIC --------------- */

  /// @notice Adds an asset to the supported assets list.
  function addSupportedAsset(address asset) public onlyOwner {
    if (asset == address(0) || asset == address(slusd) || !_supportedAssets.add(asset)) {
      revert InvalidAssetAddress();
    }
    emit AssetAdded(asset);
  }

  /// @notice Adds an custodian to the supported custodians list.
  function setCustodianAddress(address custodian) public onlyOwner {
    if (custodian == address(0) || custodian == address(slusd) || custodian == _custodianAddress) {
      revert InvalidCustodianAddress();
    }
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

  /// @notice hash an Order struct
  function hashOrder(Order calldata order) public view override returns (bytes32) {
    return ECDSA.toTypedDataHash(getDomainSeparator(), keccak256(encodeOrder(order)));
  }

  function encodeOrder(Order calldata order) public pure returns (bytes memory) {
    return abi.encode(
      orderType,
      order.orderType,
      order.expiry,
      order.nonce,
      order.benefactor,
      order.collateralAsset,
      order.collateralAmount
    );
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
      if (!_supportedAssets.contains(asset)) revert UnsupportedAsset();
      IERC20(asset).safeTransfer(beneficiary, amount);
    }
  }

  /// @notice transfer supported asset to array of custody addresses per defined ratio
  function _transferCollateralToCustodian(uint256 amount, address asset, address beneficiary) internal {
    // cannot mint using unsupported asset or native ETH even if it is supported for redemptions
    if (!_supportedAssets.contains(asset) || asset == NATIVE_TOKEN) revert UnsupportedAsset();

    IERC20 token = IERC20(asset);

    token.safeTransferFrom(beneficiary, _custodianAddress, amount);
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
