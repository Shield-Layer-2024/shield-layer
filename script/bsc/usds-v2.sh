# BSC
forge create \
    contracts/USDsV2.sol:USDsV2 \
    --chain-id 97 \
    --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 \
    --verifier-url https://api-testnet.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY \
    --verify \
    --constructor-args "0x6D71Df38Da725c4Ad62E1b500A228A76eF70bfD5" "0x15ceE6b49a157363660ed63ACa47769Fdbd35DB0"

# contructor(slusd, silo)
