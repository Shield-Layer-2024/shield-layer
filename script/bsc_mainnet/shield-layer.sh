# BSC
forge create \
    contracts/ShieldLayer.sol:ShieldLayer \
    --chain-id 56 \
    --rpc-url https://bsc-dataseed1.binance.org/ \
    --verifier-url https://api.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY_NICKY \
    --verify \
    --constructor-args \
    "0x58D5F16289B6a4F826e730Ff196D0531d44FbaB9" \
    "0x2d95899577E7Ce105eAef0079C2d6Af2A5Ce1aB1" \
    "2000000000000000000000000" \
    "2000000000000000000000000"

# constructor(
#     uslt,
#     stuslt,
#     2000000000000000000000000,
#     2000000000000000000000000,
# )
