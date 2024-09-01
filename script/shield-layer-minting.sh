# Sepolia
forge create \
    contracts/ShieldLayerMinting.sol:ShieldLayerMinting \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --private-key $EVM_PRIVATE_KEY \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --verify \
    --constructor-args "0x1481165718D57D8Caed98ad773665F394b456962" "2000000000000000000000000" "2000000000000000000000000"

forge verify-contract \
    --chain-id 11155111 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args $(cast abi-encode "constructor(address, uint256, uint256)" "0x1481165718D57D8Caed98ad773665F394b456962" "2000000000000000000000000" "2000000000000000000000000") "0x000d9035ABFdb56A8F916d94Da02E6d765e56F6D" "ShieldLayerMinting"
