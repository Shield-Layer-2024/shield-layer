// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import "../contracts/SLUSD.sol";
import "../contracts/USDsV2.sol";
import "../contracts/ShieldLayerSilo.sol";
import "../contracts/ShieldLayer.sol";
import "../contracts/RewardProxy.sol";

contract SepoliaDeploy is Script {
  function run() external {
    uint256 privateKey = vm.envUint("EVM_PRIVATE_KEY");

    bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

    address usdt = 0x55d398326f99059fF775485246999027B3197955;
    address custodian = 0x593f606F6b5c5d325AcEbA5d7f605b9a061030cB;
    address rewarder = 0x04c17Bc9C98c9cdEddfEe8204a0153Fe65997DB7;

    vm.startBroadcast(privateKey);

    SLUSD slusd = new SLUSD();
    ShieldLayerSilo silo = new ShieldLayerSilo();
    USDsV2 usds = new USDsV2(slusd, silo);
    ShieldLayer shieldlayer = new ShieldLayer(slusd, usds, 2000000000000000000000000, 2000000000000000000000000);
    RewardProxy reward = new RewardProxy(slusd, usds, shieldlayer);

    slusd.grantRole(CONTROLLER_ROLE, address(shieldlayer));
    slusd.grantRole(CONTROLLER_ROLE, address(reward));
    usds.grantRole(CONTROLLER_ROLE, address(shieldlayer));
    silo.grantRole(CONTROLLER_ROLE, address(usds));
    usds.grantRole(REWARDER_ROLE, address(reward));
    reward.grantRole(REWARDER_ROLE, rewarder);

    shieldlayer.addSupportedAsset(usdt, 1e12);
    shieldlayer.setCustodianAddress(custodian);
    usds.setCooldownDuration(7 days);

    vm.stopBroadcast();
  }
}

/*
forge script \
    script/Sepolia.s.sol:SepoliaDeploy \
    --broadcast \
    --verify \
    --chain sepolia \
    --private-key $EVM_PRIVATE_KEY \
    --rpc-url https://1rpc.io/sepolia \
    --verifier etherscan \
    --verifier-url https://api-sepolia.etherscan.io/api \
    --etherscan-api-key GS477KS4QNQTUUEHZSWP1UIBFAYDHWU9GV
*/
