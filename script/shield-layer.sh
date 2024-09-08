# Sepolia
forge create \
    contracts/ShieldLayer.sol:ShieldLayer \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --private-key $EVM_PRIVATE_KEY \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --verify \
    --constructor-args \
    "0xFFaCfE58d94B041655e46bD4f77DBDc8330c6Eaf" \
    "0x9541Cc8a324C1A11ea66BC1C68302791b0F47096" \
    "2000000000000000000000000" \
    "2000000000000000000000000"

forge verify-contract \
    --chain-id 11155111 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args \
    $(
        cast abi-encode "constructor(address, address, uint256, uint256)" \
            "0xFFaCfE58d94B041655e46bD4f77DBDc8330c6Eaf" \
            "0x9541Cc8a324C1A11ea66BC1C68302791b0F47096" \
            "2000000000000000000000000" \
            "2000000000000000000000000"
    ) \
    "0x51adD3210d76c223e54Fa4B60747A1df6E405D44" "ShieldLayer"
