# Sepolia
forge create \
    contracts/USDsV2.sol:USDsV2 \
    --chain-id 11155111 \
    --rpc-url https://sepolia.infura.io/v3/ccf0630254a74d5d9bd148b2681eca24 \
    --private-key $EVM_PRIVATE_KEY \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --verify \
    --constructor-args "0x429184F02cE0d26F82Eb91c21062deb2859E9288" "0x60156c104d41a1A6F4D9acd32b930d24218d557C"

forge verify-contract \
    --chain-id 11155111 \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args \
    $(cast abi-encode "constructor(address, address)" "0x429184F02cE0d26F82Eb91c21062deb2859E9288" "0x60156c104d41a1A6F4D9acd32b930d24218d557C") \
    "0x61EA2c16cD60070c7BB564b27201c0Cd19779c91" "USDsV2"
