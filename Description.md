# How Shield Layer Works

## Contracts

### USLT
Stable coin.

### stUSLT
Contract with some extension function of ERC-4626.
    
### ShieldLayer
Main contract, provide subscription, redemption and other functions.

### ShieldLayerSilo
The Silo allows to store USLT during the stake cooldown process.

### RewardProxy
This contract just a utility contract that simplify transfer in reward

## Core Functions

- USLT
  - `mint`

- stUSLT
  - `deposit`
    Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens
  - `cooldownShares`
    redeem shares into assets and starts a cooldown to claim the converted underlying asset
  - `unstake`
    Claim the staking amount after the cooldown has finished. The address can only retire the full amount of assets. 
  - `transferInRewards`
    Allows specific addresses to transfer rewards(USLT) into this contract

- ShieldLayer
  - `mintAndStake`
    Mint stable coins from assets and mint shares
  - `redeem`
    Redeem stable coins for assets

## Business Workflow

### Mint And Stake

1. transfer exactly amount from caller to custodian address
2. calculate how many USLT that caller will received
3. deposit the USLT quantity calculated in the previous step

### Unstake

The unstake is a two-step process.

#### Cooldown

1. calculate how many USLT that caller will receive
2. add quantity and new expiration timestamp to cooldown storage
3. burn stUSLT from caller

#### Unstake

1. check if the latest unstake cooldown has passed expired timestamp
2. cleanup cooldown storage
3. transfer USLT from silo contract to caller address

### Redeem

1. calculate how many asset that caller will receive
2. burn USLT from caller address
3. transfer asset from ShieldLayer contract to caller address