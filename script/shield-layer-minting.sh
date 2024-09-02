# Sepolia
forge create \
    contracts/ShieldLayerMinting.sol:ShieldLayerMinting \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --private-key $EVM_PRIVATE_KEY \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --verify \
    --constructor-args "0xef9Be0440b3A8Fc4ea3dDbe8625D99048E48F322" "2000000000000000000000000" "2000000000000000000000000"

forge verify-contract \
    --chain-id 11155111 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args \
    $(cast abi-encode "constructor(address, uint256, uint256)" "0xef9Be0440b3A8Fc4ea3dDbe8625D99048E48F322" "2000000000000000000000000" "2000000000000000000000000") \
    "0x2a4FBEBB5f43aA08B0B757b167Ad43650eB98BF3" "ShieldLayerMinting"
