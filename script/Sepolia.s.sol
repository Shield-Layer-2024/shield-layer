// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/USLT.sol";
import "../contracts/stUSLTv2.sol";
import "../contracts/ShieldLayerSilo.sol";
import "../contracts/ShieldLayer.sol";
import "../contracts/RewardProxy.sol";

contract SepoliaDeploy is Script {
  function run() external {
    uint256 privateKey = vm.envUint("EVM_PRIVATE_KEY");

    bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

    address stable = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    // address custodian = 0x593f606F6b5c5d325AcEbA5d7f605b9a061030cB;
    address rewarder = 0x04c17Bc9C98c9cdEddfEe8204a0153Fe65997DB7;

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
    shieldlayer.setCustodianAddress(address(shieldlayer));
    stuslt.setCooldownDuration(60 seconds);

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
