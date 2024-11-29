forge create \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --constructor-args "0x04c17bc9c98c9cdeddfee8204a0153fe65997db7" \
    --private-key 0xae2c634eb0826b064ef7532c15641cfa45f0fcc1a273f9342b4c57263ef0c811 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --verify \
    contracts/stUSLT.sol:stUSLT

forge test \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24
