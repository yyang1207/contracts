// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";  
import {IERC721Receiver} from"@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Weth} from "../src/Weth.sol";
import {INftAuction} from "../src/INftAuction.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NftAuctionWithDeposit is INftAuction,IERC721Receiver, ReentrancyGuard 
{

    enum AuctionStatus {
        Active,      // 0
        Settled,     // 1
        Cancelled,   // 2
        Defaulted    // 3
    }

    struct GoodsInfoWithDeposit
    {
        address seller;
        uint256 tokenId;
        uint256 startLine;
        uint256 bidDeadline;
        uint256 settleDeadline;
        uint128 startingPrice;
        uint16 depositRatio;
        AuctionStatus status;
    }

    Weth private immutable WETH;
    IERC721 private immutable NFTMANAGER;
    mapping(uint256 => BidInfo) bidderToPrice; // tokenid=>
    mapping(uint256 => GoodsInfoWithDeposit) goodsInfo; // tokenid=>
    mapping(uint256 => address) goodsOwner; // tokenid=>owner
    mapping(address => uint256) public deposit; // deposit
    uint16 public immutable MAX_DEPOSIT_RATIO; // 30%
    uint16 public immutable MIN_DEPOSIT_RATIO; // 10%

    error NotInAuctionPeriod();
    error DepositTooSmall();
    error InvalidDepositRatio();
    error InvalidLockDuration();
    error InvalidBidDuration();
    error InvalidSettleDuration();
    
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
        NFTMANAGER = IERC721(erc721Address);
        WETH = Weth(wethAddress);
        MAX_DEPOSIT_RATIO = _maxDepositRatio;
        MIN_DEPOSIT_RATIO = _minDepositRatio;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external view override returns (bytes4) {
        if (msg.sender != address(NFTMANAGER)) revert NotOwner();
        if (tokenId == 0) revert InvalidTokenId();
        if (from != goodsOwner[tokenId]) revert NotSeller();


        return this.onERC721Received.selector;
    }

    function addGoodsToAuction(
        uint256 goodsId,
        uint128 initPrice,
        uint256 lockDuration,
        uint256 bidDuration,
        uint256 settleDuration,
        uint16 depositRatio
    ) external returns (bool) {
        if (initPrice <= 0) revert InvalidPrice();

 
        if (lockDuration < 50) revert InvalidLockDuration();
        if (bidDuration < 1800) revert InvalidBidDuration();
        if (settleDuration<300) revert InvalidSettleDuration();

        if (depositRatio < MIN_DEPOSIT_RATIO || depositRatio > MAX_DEPOSIT_RATIO) revert  InvalidDepositRatio();
        if (bidderToPrice[goodsId].bidder != address(0))
            revert GoodsAlreadyInAuction();
        if (msg.sender != NFTMANAGER.ownerOf(goodsId)) revert SellerNotMatch();

        //init goods info
        goodsInfo[goodsId] = GoodsInfoWithDeposit({
            seller: NFTMANAGER.ownerOf(goodsId),
            tokenId: goodsId,
            startingPrice: initPrice,
            startLine: block.number + lockDuration, 
            bidDeadline: block.number + lockDuration + bidDuration, 
            settleDeadline: block.number + lockDuration + bidDuration + settleDuration, 
            depositRatio: depositRatio,
            status: AuctionStatus.Active
        });

        // init bidder info
        bidderToPrice[goodsId] = BidInfo({
            bidder: address(0),
            price: initPrice
        });

        // transfer goods from seller to contract
        goodsOwner[goodsId] = msg.sender;
        NFTMANAGER.safeTransferFrom(msg.sender, address(this), goodsId);

        return true;
    }

    function sellerWithdraw(uint256 goodsId) external nonReentrant returns (bool) {
        if (msg.sender != goodsInfo[goodsId].seller) revert OnlySeller();
        if (address(0) != bidderToPrice[goodsId].bidder) revert GoodsInAucting();
        goodsInfo[goodsId].status = AuctionStatus.Cancelled;

        NFTMANAGER.safeTransferFrom(address(this), msg.sender, goodsInfo[goodsId].tokenId);
        return true;
    }

    function _beforebid(uint256 goodsId, uint256 price,GoodsInfoWithDeposit memory goods,BidInfo memory bidinfo) private view
    {
        if (msg.sender == address(0)) revert InvalidBidder();
        if (goodsId == 0) revert InvalidTokenId();
        if (price == 0) revert InvalidPrice();

        if (msg.sender == goods.seller) revert SellerCannotBid();
        if (goods.status != AuctionStatus.Active || block.number < goods.startLine || block.number >= goods.bidDeadline)
            revert NotInAuctionPeriod();
        
        uint256 depositAmount = price * goods.depositRatio / 10000;
        if(depositAmount == 0) revert DepositTooSmall();
        if (price <= bidinfo.price) revert InvalidPrice();
    }

    function bid(uint256 goodsId, uint256 price) external nonReentrant returns (bool) {
        GoodsInfoWithDeposit memory goods = goodsInfo[goodsId];
        BidInfo memory bidinfo = bidderToPrice[goodsId];

        _beforebid(goodsId, price, goods, bidinfo);

        //set old bidder's deposit
        uint256 depositAmount = price * goods.depositRatio / 10000;
        address oldBidder = bidinfo.bidder;        

        // update bidder info
        bidderToPrice[goodsId] = BidInfo({bidder: msg.sender, price: price});
        deposit[msg.sender] = depositAmount;

        
        // refund old bidder's deposit
        _dealDeposit(goodsId, oldBidder, depositAmount);

        emit BidPlaced(goodsId, msg.sender, price, depositAmount);

        return true;
    }

    function _dealDeposit(uint256 goodsId, address oldBidder, uint256 depositAmount) private 
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

                emit DepositRefunded(goodsId, oldBidder, oldDeposit);
            }
        }

        //transfer weth from bidder to contract
        bool success = WETH.transferFrom(msg.sender, address(this), depositAmount);
        if (!success) revert DepositTransferFailed();
    }

    function getLastBidder(
        uint256 goodsId
    ) external view returns (address, uint256) {
        BidInfo memory bidder = bidderToPrice[goodsId];
        return (bidder.bidder, bidder.price);
    }

    function settle(uint256 goodsId) external nonReentrant returns (bool) {
        GoodsInfoWithDeposit storage goods = goodsInfo[goodsId];
        if (goods.status != AuctionStatus.Active) revert AuctionAlreadySettled();
        if (block.number <= goods.bidDeadline) revert GoodsInAucting();
        if(block.number > goods.settleDeadline) revert SettlementPeriodExpired();

        BidInfo memory bidinfo = bidderToPrice[goodsId];
        if (msg.sender != bidinfo.bidder) revert NotWinner();

        //update goods info
        goods.status = AuctionStatus.Settled;

        // transfer remaining balance to seller
        uint256 winnerPrice = bidinfo.price;
        uint256 winnerId = goods.tokenId;
        uint256 depositPaid = deposit[msg.sender]; 
        uint256 remainingToPay = winnerPrice - depositPaid;
        if(depositPaid > 0)
        {
            deposit[msg.sender] = 0;
            bool succPay = WETH.transfer(goods.seller, depositPaid);
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
        NFTMANAGER.safeTransferFrom(address(this), bidinfo.bidder, winnerId);

        emit AuctionSettled(goodsId, msg.sender, depositPaid, remainingToPay);

        return true;
    }

    function claimPenalty(uint256 goodsId) external nonReentrant {
        GoodsInfoWithDeposit storage goods = goodsInfo[goodsId];
        
        if(msg.sender != goods.seller) revert OnlySeller();
        if(goods.status != AuctionStatus.Active) revert AuctionAlreadySettled();

        if(block.number <= goods.settleDeadline) revert SettlementPeriodActived();
        
 
        goods.status = AuctionStatus.Defaulted;
        

        address winner = bidderToPrice[goodsId].bidder;
        uint256 forfeitDeposit = deposit[winner];
 
        if (forfeitDeposit > 0) 
        {
            deposit[winner] = 0;
            require(WETH.transfer(goods.seller, forfeitDeposit), "Deposit transfer failed");
        }
        

        NFTMANAGER.safeTransferFrom(address(this), goods.seller, goods.tokenId);
        
  
        emit AuctionPenalized(goodsId, winner, forfeitDeposit);
    }
}