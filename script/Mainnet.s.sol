// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/USLT.sol";
import "../contracts/stUSLTv2.sol";
import "../contracts/ShieldLayerSilo.sol";
import "../contracts/ShieldLayer.sol";
import "../contracts/RewardProxy.sol";

contract MainnetDeploy is Script {
  function run() external {
    uint256 privateKey = vm.envUint("EVM_PRIVATE_KEY_NICKY");

    bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

    address stable = 0xdAC17F958D2ee523a2206206994597C13D831ec7;  // USDT
    address custodian = 0x0ca44643440D319955F7Ad7D62c8d35347573c62;  // fire-blocks
    address rewarder = 0x6288ab08FA2a53500377fAdF0677462390621bf8;

    vm.startBroadcast(privateKey);

    USLT uslt = new USLT();
    ShieldLayerSilo silo = new ShieldLayerSilo();
    stUSLTv2 stuslt = new stUSLTv2(uslt, silo);
    ShieldLayer shieldlayer = new ShieldLayer(uslt, stuslt, 2000000000000000000000000, 2000000000000000000000000);
    RewardProxy reward = new RewardProxy(uslt, stuslt, shieldlayer);

    uslt.grantRole(CONTROLLER_ROLE, address(shieldlayer));
    uslt.grantRole(CONTROLLER_ROLE, address(reward));
    stuslt.grantRole(CONTROLLER_ROLE, address(shieldlayer));
    silo.grantRole(CONTROLLER_ROLE, address(stuslt));
    stuslt.grantRole(REWARDER_ROLE, address(reward));
    reward.grantRole(REWARDER_ROLE, rewarder);

    shieldlayer.addSupportedAsset(stable, 10 ** (18 - ERC20(stable).decimals()));
    shieldlayer.setCustodianAddress(custodian);
    stuslt.setCooldownDuration(5 days);

    vm.stopBroadcast();
  }
}

/*
forge script \
    script/Mainnet.s.sol:MainnetDeploy \
    --broadcast \
    --verify \
    --chain mainnet \
    --private-key $EVM_PRIVATE_KEY_NICKY \
    --rpc-url https://mainnet.infura.io/v3/eb6afaaab98043f9b6bfeec22d24beae \
    --verifier etherscan \
    --verifier-url https://api.etherscan.io/api \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV \
    --delay 5
*/
