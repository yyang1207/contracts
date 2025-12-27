// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC721Receiver} from"@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {INftAuction,IWETHExtended} from "../src/INftAuction.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {NFT1155Wrapper} from "../src/NFT1155Wrapper.sol";

contract AuctionWrapERC1155WithDeposit is INftAuction,IERC721Receiver, ReentrancyGuard 
{
    struct BidInfo
    {
        address bidder;
        uint256 price;
        uint256 bidDeadline;
    }

    enum AuctionStatus {
        Active,      // 0
        Settled,     // 1
        Cancelled,   // 2
        Defaulted    // 3
    }

    struct GoodsInfoWithDeposit
    {
        address seller;
        uint256 wrapperTokenId;
        uint256 startLine;
        uint256 bidDeadline;
        uint128 startingPrice;
        uint16 settleDuration;
        uint16 depositRatio;
        uint16 cutDownDuration;
        uint16 minIncreamentRatio;
        AuctionStatus status;
    }

    IWETHExtended private immutable WETH;
    NFT1155Wrapper private immutable NFTMANAGER;
    mapping(uint256 => BidInfo) bidderToPrice; // auctionId=>
    mapping(uint256 => GoodsInfoWithDeposit) goodsInfo; // auctionId=>
    mapping(address => uint256) public deposit; // deposit
    uint256 public auctionNftId; // nftId
    uint16 public immutable MAX_DEPOSIT_RATIO; // 30%
    uint16 public immutable MIN_DEPOSIT_RATIO; // 10%
    uint8 public serviceFeeRatio=1; // 1%

    

    error InvalidDepositRatio();
    error InvalidLockDuration();
    error InvalidBidDuration();
    error InvalidSettleDuration();
    error InvalidCutdownDuration();
    error InvalidIncreamentRatio();
    error CannotConsecutiveBid();

    error BidCutdownFinished();
    error DepositTooSmall();
    error NotInAuctionPeriod();
    
    error RefundFailed();
    error DepositTransferFailed();
    error PaidDepositFailed();
    error PaidRemainingFailed();

    error SettlementPeriodExpired();
    error SettlementPeriodActived();


    event BidPlaced(uint256 indexed goodsId, address indexed bidder, uint256 price, uint256 deposit);
    event DepositRefunded(uint256 indexed goodsid, address indexed bidder, uint256 deposit);
    event AuctionSettled(uint256 indexed goodsId, address indexed winner, uint256 deposit,uint256 remaining);
    event AuctionPenalized(uint256 indexed goodsId, address indexed winner, uint256 deposit);

    constructor(
        address erc721Address,
        address wethAddress,
        uint16 _maxDepositRatio,
        uint16 _minDepositRatio
    ) {
        NFTMANAGER = NFT1155Wrapper(erc721Address);
        WETH = IWETHExtended(wethAddress);
        MAX_DEPOSIT_RATIO = _maxDepositRatio;
        MIN_DEPOSIT_RATIO = _minDepositRatio;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external view override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function addGoodsToAuction(
        uint256 wrapTokenId,
        uint128 initPrice,
        uint256 lockDuration,
        uint256 bidDuration,
        uint16 settleDuration,
        uint16 depositRatio,
        uint16 cutDown,
        uint16 increament
    ) external returns (bool) 
    {

        if (initPrice <= 0) revert InvalidPrice();

 
        if (lockDuration < 50) revert InvalidLockDuration();
        if (bidDuration < 1800) revert InvalidBidDuration();
        if (settleDuration<300) revert InvalidSettleDuration();
        if(cutDown<50) revert InvalidCutdownDuration();
        if(increament<5) revert InvalidIncreamentRatio();

        if (depositRatio < MIN_DEPOSIT_RATIO || depositRatio > MAX_DEPOSIT_RATIO) revert  InvalidDepositRatio();
        if (depositRatio < serviceFeeRatio) revert InvalidDepositRatio();
        //if (bidderToPrice[goodsId].bidder != address(0)) revert GoodsAlreadyInAuction();
        if (msg.sender != NFTMANAGER.ownerOf(wrapTokenId)) revert SellerNotMatch();

        auctionNftId++;

        //init goods info
        uint256 start = block.number + lockDuration;
        uint256 biddl = start + bidDuration;
        goodsInfo[auctionNftId] = GoodsInfoWithDeposit({
            seller: msg.sender,
            tokenId: wrapTokenId,
            startingPrice: initPrice,
            startLine: start, 
            bidDeadline: biddl, 
            settleDuration: settleDuration, 
            depositRatio: depositRatio,
            cutDownDuration: cutDown,
            minIncreamentRatio: increament,
            status: AuctionStatus.Active
        });

        // init bidder info
        bidderToPrice[auctionNftId] = BidInfo({
            bidder: address(0),
            price: initPrice,
            bidDeadline: biddl
        });

        // transfer goods from seller to contract
        NFTMANAGER.safeTransferFrom(msg.sender, address(this), wrapTokenId);

        return true;
    }

    function sellerWithdraw(uint256 auctionId) external nonReentrant returns (bool) {
        if (msg.sender != goodsInfo[auctionId].seller) revert OnlySeller();
        if (address(0) != bidderToPrice[auctionId].bidder) revert GoodsInAucting();
        goodsInfo[auctionId].status = AuctionStatus.Cancelled;

        NFTMANAGER.safeTransferFrom(address(this), msg.sender, goodsInfo[auctionId].tokenId);
        return true;
    }

    function _beforebid(uint256 auctionId, uint256 price,GoodsInfoWithDeposit memory goods,BidInfo memory bidinfo) private view
    {
        if (msg.sender == address(0)) revert InvalidBidder();
        if (auctionId == 0) revert InvalidTokenId();
        if(goods.seller==address(0)) revert InvalidSeller();
        if(bidinfo.bidder==address(0)) revert InvalidBidder();
        if(msg.sender == bidinfo.bidder) revert CannotConsecutiveBid();

        if (msg.sender == goods.seller) revert SellerCannotBid();
        if (goods.status != AuctionStatus.Active || block.number < goods.startLine || block.number >= goods.bidDeadline)
            revert NotInAuctionPeriod();

        if(block.number >= bidinfo.bidDeadline) revert BidCutdownFinished();
        
        uint256 depositAmount = price * goods.depositRatio / 10000;
        if(depositAmount == 0) revert DepositTooSmall();
        if (price < bidinfo.price*(100+goods.minIncreamentRatio)/100) revert InvalidPrice();
    }

    function bid(uint256 auctionId, uint256 price) external nonReentrant returns (bool) {
        GoodsInfoWithDeposit memory goods = goodsInfo[auctionId];
        BidInfo memory bidinfo = bidderToPrice[auctionId];

        _beforebid(auctionId, price, goods, bidinfo);

        //set old bidder's deposit
        uint256 depositAmount = price * goods.depositRatio / 10000;
        address oldBidder = bidinfo.bidder;        

        // update bidder info
        uint256 biddl=block.number + goods.cutDownDuration;
        bidderToPrice[auctionId] = BidInfo({bidder: msg.sender, price: price, bidDeadline: biddl<goods.bidDeadline? biddl:goods.bidDeadline});
        deposit[msg.sender] = depositAmount;

        
        // refund old bidder's deposit
        _dealDeposit(auctionId, oldBidder, depositAmount);

        emit BidPlaced(auctionId, msg.sender, price, depositAmount);

        return true;
    }

    function _dealDeposit(uint256 auctionId, address oldBidder, uint256 depositAmount) private 
    {
        //refund old bidder's deposit
        if (oldBidder!= address(0)) 
        {
            uint256 oldDeposit = deposit[oldBidder];
            if(oldDeposit>0)
            {
                deposit[oldBidder] = 0;
                bool succRefund = WETH.transfer(oldBidder, oldDeposit);
                if (!succRefund) revert RefundFailed();

                emit DepositRefunded(auctionId, oldBidder, oldDeposit);
            }
        }

        //transfer weth from bidder to contract
        bool success = WETH.transferFrom(msg.sender, address(this), depositAmount);
        if (!success) revert DepositTransferFailed();
    }

    function getLastBidder(
        uint256 auctionId
    ) external view returns (address, uint256) {
        BidInfo memory bidder = bidderToPrice[auctionId];
        return (bidder.bidder, bidder.price);
    }

    function settle(uint256 auctionId) external nonReentrant returns (bool) {
        GoodsInfoWithDeposit storage goods = goodsInfo[auctionId];
        BidInfo memory bidinfo = bidderToPrice[auctionId];
        if (goods.status != AuctionStatus.Active) revert AuctionAlreadySettled();
        if (block.number <= bidinfo.bidDeadline) revert GoodsInAucting();
        if(block.number > bidinfo.bidDeadline + goods.settleDuration) revert SettlementPeriodExpired();

        
        if (msg.sender != bidinfo.bidder) revert NotWinner();

        //update goods info
        goods.status = AuctionStatus.Settled;

        // transfer remaining balance to seller
        uint256 winnerPrice = bidinfo.price;
        uint256 tokenId = goods.wrapTokenId;
        uint256 depositPaid = deposit[msg.sender]; 
        uint256 remainingToPay = winnerPrice - depositPaid;
        if(depositPaid > 0)
        {
            deposit[msg.sender] = 0;
            uint256 serviceFee = winnerPrice * serviceFeeRatio / 100;
            uint256 remainingDeposit = depositPaid - serviceFee;
            bool succPay = WETH.transfer(goods.seller, remainingDeposit);
            if (!succPay) revert PaidDepositFailed();
        }
        if(remainingToPay > 0)
        {
            bool success = WETH.transferFrom(
                msg.sender,
                goods.seller,
                remainingToPay
            );
            if (!success) revert PaidRemainingFailed();
        }

        // transfer goods to winner
        NFT1155Wrapper(wrapperContract).unwrapTo(tokenId, bidinfo.bidder);

        emit AuctionSettled(auctionId, msg.sender, depositPaid, remainingToPay);

        return true;
    }

    function claimPenalty(uint256 auctionId) external nonReentrant {
        GoodsInfoWithDeposit storage goods = goodsInfo[auctionId];
        BidInfo memory winBid = bidderToPrice[auctionId];
        address winner = winBid.bidder;

        if(msg.sender != goods.seller) revert OnlySeller();
        if(goods.status != AuctionStatus.Active) revert AuctionAlreadySettled();

        if(block.number <= winBid.bidDeadline + goods.settleDuration) revert SettlementPeriodActived();
        
 
        goods.status = AuctionStatus.Defaulted;
        

   
        uint256 forfeitDeposit = deposit[winner];
 
        if (forfeitDeposit > 0) 
        {
            deposit[winner] = 0;
            require(WETH.transfer(goods.seller, forfeitDeposit), "Deposit transfer failed");
        }
        

        NFTMANAGER.safeTransferFrom(address(this), goods.seller, goods.wrapTokenId);
        
  
        emit AuctionPenalized(auctionId, winner, forfeitDeposit);
    }
}