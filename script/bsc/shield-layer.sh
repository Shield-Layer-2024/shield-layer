# BSC
forge create \
    contracts/ShieldLayer.sol:ShieldLayer \
    --chain-id 97 \
    --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 \
    --verifier-url https://api-testnet.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY \
    --verify \
    --constructor-args \
    "0x6D71Df38Da725c4Ad62E1b500A228A76eF70bfD5" \
    "0xd287Cc6337f23E65d2B04F45165E7c854bEe059c" \
    "2000000000000000000000000" \
    "2000000000000000000000000"

# constructor(
#     slusd,
#     usds,
#     2000000000000000000000000,
#     2000000000000000000000000,
# )
