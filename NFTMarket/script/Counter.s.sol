// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract CounterScript is Script {
    Counter public counter;

    function setUp() public {}

    function run() public {
        // 1. 获取私钥 (请务必安全保管)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 2. 部署合约
        vm.startBroadcast(deployerPrivateKey);
        counter = new Counter();

        // 3. 保存合约地址
        vm.saveAddress("counter", address(counter));

        // 4. 保存合约部署者私钥
        vm.stopBroadcast();
    }
}
