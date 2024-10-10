# BSC Testnet
forge create \
    contracts/mock/MockUSDT.sol:MockUSDT \
    --chain-id 97 \
    --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 \
    --verifier-url https://api-testnet.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY \
    --verify

forge verify-contract \
    --chain-id 97 \
    --verifier-url https://api-testnet.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --compiler-version "0.8.19+commit.7dd6d404" \
    --constructor-args \
    $(cast abi-encode "constructor()") \
    "0xFFaCfE58d94B041655e46bD4f77DBDc8330c6Eaf" "SLUSD"
