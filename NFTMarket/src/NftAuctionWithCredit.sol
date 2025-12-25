// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";  
import {IERC721Receiver} from"@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {INftAuction,IWETHExtended} from "../src/INftAuction.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";



contract NftAuctionWithCredit is INftAuction,IERC721Receiver, ReentrancyGuard {

    struct  GoodsInfo 
    {
        address seller;
        uint256 tokenId;
        uint256 startingPrice;
        uint256 endTime;
        bool isEnded;
    }

    struct BidInfo
    {
        address bidder;
        uint256 price;
    }

    IWETHExtended private immutable weth;
    IERC721 private immutable erc721;
    mapping (uint256 => BidInfo) bidderToPrice; // 场次id=>tokenid=>竞价信息
    mapping (uint256 => GoodsInfo) goodsInfo; // 场次id=>tokenid=>商品信息
    mapping (uint256 => address) goodsOwner;// tokenid=>所属人

    constructor(address erc721Address,address wethAddress)
    {
        weth = IWETHExtended(wethAddress);
        erc721 = IERC721(erc721Address);
    }

    // 实现 ERC721 接收接口
    function onERC721Received(
        address,
        address from,
        uint256 receivedTokenId,
        bytes calldata
    ) external view override returns (bytes4) 
    {
        if(msg.sender != address(erc721)) revert NotOwner();
        if(receivedTokenId ==0) revert InvalidTokenId();
        if(from != goodsOwner[receivedTokenId]) revert NotSeller();
        
        // 返回正确的 selector
        return this.onERC721Received.selector;
    }

    function addGoodsToAuction(uint256 goodsId,uint256 initPrice,uint256 endTime) external returns (bool)  {
        if(initPrice <= 0)revert InvalidPrice();
        if(endTime<=3600) revert InvalidEndTime();
        if(msg.sender==address(0))revert InvalidSeller();
        if(bidderToPrice[goodsId].bidder != address(0))revert GoodsAlreadyInAuction();
        if(msg.sender != erc721.ownerOf(goodsId)) revert SellerNotMatch();

        //init goods info
        goodsInfo[goodsId] = GoodsInfo(
        {
            seller: erc721.ownerOf(goodsId),
            tokenId:goodsId,
            startingPrice: initPrice,
            endTime: block.number + endTime, // 截止时间
            isEnded: false
        });

        // init bidder info
        bidderToPrice[goodsId] = BidInfo(
        {
            bidder: msg.sender,
            price: initPrice
        });

        
        // transfer goods from seller to contract
        goodsOwner[goodsId] = msg.sender;
        erc721.safeTransferFrom(msg.sender, address(this), goodsId);

        return true;
    }

    function sellerWithdraw(uint256 goodsId) external returns (bool)  
    {
        if(msg.sender != goodsInfo[goodsId].seller)revert OnlySeller();
        if(msg.sender != bidderToPrice[goodsId].bidder)revert NotOwner();
        goodsInfo[goodsId].isEnded = true;

        erc721.safeTransferFrom(address(this), msg.sender, goodsId);
        return true;
    }

    function bid(uint256 goodsId,uint256 price) external returns (bool)  
    {
        if(msg.sender==address(0))revert InvalidBidder();
        if(goodsId==0)revert InvalidTokenId();
        if(price==0)revert InvalidPrice();

        GoodsInfo memory goods = goodsInfo[goodsId];
        if(msg.sender == goods.seller) revert NotSeller();
        if(goods.isEnded || block.number >= goods.endTime) revert AuctionEnded();

        BidInfo storage bidinfo=bidderToPrice[goodsId];
        if(price <= bidinfo.price)revert InvalidPrice();
        if(weth.balanceOf(msg.sender)<price) revert NotEnoughBalance();

        // update bidder info
        bidderToPrice[goodsId] = BidInfo(
        {
            bidder: msg.sender,
            price: price
        });

        return true;
    }

    function getLastBidder(uint256 goodsId) external view returns (address,uint256)  {
        BidInfo memory bidder = bidderToPrice[goodsId];
        return (bidder.bidder,bidder.price);
    }

    function settle(uint256 goodsId) external returns (bool)  
    {
        GoodsInfo storage goods = goodsInfo[goodsId];
        if(goods.isEnded) return (true);
        if(msg.sender == goods.seller)revert NotBidder();
        if(block.number <= goods.endTime)revert GoodsInAucting();

        BidInfo memory bidinfo = bidderToPrice[goodsId];
        if(msg.sender != bidinfo.bidder) revert NotOwner();
        goods.isEnded=true;

        // transfer goods to winner
        uint256 winnerPrice = bidinfo.price;
        uint256 winnerId = goods.tokenId;
        erc721.safeTransferFrom(address(this), bidinfo.bidder, winnerId);

        // transfer remaining balance to seller
        uint256 balance = weth.balanceOf(bidinfo.bidder);
        if(balance < winnerPrice)revert NotEnoughBalance();
        bool success=weth.transferFrom(bidinfo.bidder,goods.seller,winnerPrice);
        if(!success)revert NotEnoughBalance();

        return true;
    }
}