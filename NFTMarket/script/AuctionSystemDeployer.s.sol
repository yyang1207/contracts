// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NftERC721} from "../src/NftERC721.sol";
import {Weth} from "../src/Weth.sol";
import {NftAuctionWithDeposit} from "../src/NftAuctionWithDeposit.sol";

contract AuctionSystemDeployer is Script 
{
    address public auction;
    address public erc721;
    address public weth;

    function setUp() public {}

    function run() public 
    {
        // 1. 从环境变量获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        //部署erc721合约
        NftERC721 nft = new NftERC721();
        erc721 = address(nft);
        console.log("erc721 address: {}", erc721);

        //部署weth合约
        Weth erc20 = new Weth();
        weth = address(erc20);
        console.log("weth address: {}", weth);

        //部署auction合约
        NftAuctionWithDeposit nftAuction = new NftAuctionWithDeposit(erc721, weth,2,30);
        auction = address(nftAuction);
        console.log("auction address: {}", auction);

        // 2. 广播交易
        vm.stopBroadcast();
    }
}