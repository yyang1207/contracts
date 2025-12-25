// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {IWETH} from "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

interface IWETHExtended is IWETH {
    // 补上从 public mapping 自动生成的 getter 函数
    function balanceOf(address owner) external view returns (uint256);
    
    // 同时强烈建议补上拍卖合约必需的其他ERC20标准函数
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    // 可选：如果需要，也可以加上 totalSupply(), name(), symbol(), decimals()
}

interface INftAuction 
{
    

    error InvalidEndTime();
    error InvalidBidder();
    error InvalidTokenId();
    error InvalidPrice();
    error InvalidSeller();
    error GoodsAlreadyInAuction();
    error SellerNotMatch();
    error OnlySeller();
    error NotSeller();
    error NotOwner();
    error NotBidder();
    error AuctionEnded();
    error NotEnoughBalance();
    error GoodsInAucting();
    error SellerCannotBid();
    error AuctionAlreadySettled();
    error NotWinner();

    function sellerWithdraw(uint256 goodsId) external returns (bool);
    function bid(uint256 goodsId,uint256 price) external returns (bool);
    function getLastBidder(uint256 goodsId) external view returns (address,uint256);
    function settle(uint256 goodsId) external returns (bool);
}