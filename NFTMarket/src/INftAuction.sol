// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;


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