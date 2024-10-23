# BSC
forge create \
    contracts/ShieldLayerSilo.sol:ShieldLayerSilo \
    --chain-id 56 \
    --rpc-url https://bsc-dataseed1.binance.org/ \
    --verifier-url https://api.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY_NICKY \
    --verify
