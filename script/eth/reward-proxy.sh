# Sepolia
forge create \
    contracts/RewardProxy.sol:RewardProxy \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --verifier-url https://api-sepolia.etherscan.io/api \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --private-key $EVM_PRIVATE_KEY \
    --verify \
    --constructor-args \
    "0xFFaCfE58d94B041655e46bD4f77DBDc8330c6Eaf" \
    "0x9541Cc8a324C1A11ea66BC1C68302791b0F47096" \
    "0xBe7EFd1C1FAF4B0F8ec936A07657167CAbb670f3"


forge verify-contract \
    --chain-id 11155111 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args \
    $(cast abi-encode "constructor()") \
    "0x74e8D069954dB85eea7c2F08e2e1488473b0cDba" "MockUSDT"