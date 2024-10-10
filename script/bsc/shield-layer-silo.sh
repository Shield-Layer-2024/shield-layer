# BSC
forge create \
    contracts/ShieldLayerSilo.sol:ShieldLayerSilo \
    --chain-id 97 \
    --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 \
    --verifier-url https://api-testnet.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY \
    --verify
