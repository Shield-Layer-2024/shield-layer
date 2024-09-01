# Sepolia
forge create \
    contracts/slUSD.sol:slUSD \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --private-key $EVM_PRIVATE_KEY \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --verify \
    --constructor-args "0x04c17bc9c98c9cdeddfee8204a0153fe65997db7"

forge verify-contract \
    --chain-id 11155111 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args $(cast abi-encode "constructor(address)" "0x04c17Bc9C98c9cdEddfEe8204a0153Fe65997DB7") "0x1481165718D57D8Caed98ad773665F394b456962" "slUSD"
