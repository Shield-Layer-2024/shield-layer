# BSC
forge create \
    contracts/USDsV2.sol:USDsV2 \
    --chain-id 56 \
    --rpc-url https://bsc-dataseed1.binance.org/ \
    --verifier-url https://api.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY_NICKY \
    --verify \
    --constructor-args "0x58D5F16289B6a4F826e730Ff196D0531d44FbaB9" "0xE649fF12a4f9b20882839c9C293C960A15acCbD1"

# contructor(slusd, silo)
