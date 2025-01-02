# BSC
forge create \
    contracts/USLT.sol:USLT \
    --chain-id 56 \
    --rpc-url https://bsc-dataseed1.binance.org/ \
    --verifier-url https://api.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --private-key $EVM_PRIVATE_KEY_NICKY \
    --verify


forge verify-contract \
    --chain-id 56 \
    --rpc-url https://bsc-dataseed1.binance.org/ \
    --verifier-url https://api.bscscan.com/api \
    --etherscan-api-key A4UN3IJEE6PAEEWVVVYCKXFMSKTZ1DIYCP \
    --compiler-version "0.8.28+commit.7893614a" \
    --constructor-args \
    $(cast abi-encode "constructor()") \
    "0x59f3b0e8b4c363c3cfb17c223b194fa75ef72cee" "USLT"