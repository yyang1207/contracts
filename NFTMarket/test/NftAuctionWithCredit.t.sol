// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {NftAuctionWithCredit} from "../src/NftAuctionWithCredit.sol";
import {NftERC721} from "../src/NftERC721.sol";
import {Weth} from "../src/Weth.sol";

contract NftAuctionWithCreditTest is Test 
{
    address public seller = makeAddr("seller");
    address public bidder1 = makeAddr("bidder1");
    address public bidder2 = makeAddr("bidder2");
    address public bidder3 = makeAddr("bidder3");

    NftAuctionWithCredit nftAuction;
    NftERC721 erc721;
    Weth weth;

    function setUp() public 
    {
        //构造weth
        weth = new Weth();

        //构造nft
        erc721 = new NftERC721();
        erc721.mint(seller, 1);
        erc721.mint(seller, 2);
        erc721.mint(seller, 11);
        erc721.mint(seller, 22);

        //构造nftAuction
        nftAuction = new NftAuctionWithCredit(address(erc721),address(weth));

        //添加余额
        vm.deal(bidder1, 1000000 ether);
        vm.deal(bidder2, 1000000 ether);
        vm.deal(bidder3, 1000000 ether);

        vm.startPrank(bidder1);
        weth.deposit{value: 100000 ether}();
        weth.approve(address(nftAuction), 100000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        weth.deposit{value: 100000 ether}();
        weth.approve(address(nftAuction), 100000 ether);
        vm.stopPrank();

        vm.startPrank(bidder3);
        weth.deposit{value: 100000 ether}();
        weth.approve(address(nftAuction), 100000 ether);
        vm.stopPrank();


        //授信
        vm.startPrank(seller);
        erc721.approve(address(nftAuction), 1);
        erc721.approve(address(nftAuction), 2);
        erc721.approve(address(nftAuction), 11);
        erc721.approve(address(nftAuction), 22);
        vm.stopPrank();

        vm.startPrank(seller);
        bool success = nftAuction.addGoodsToAuction(11, 1000, 1 days);
        assertEq(success, true);
        vm.stopPrank();

        vm.startPrank(seller);
        success = nftAuction.addGoodsToAuction(22, 1000, 1 days);
        assertEq(success, true);
        vm.stopPrank();
    }

    function test_addGoodsToAuction() public {
        // TODO: implement test
        vm.startPrank(seller);
        bool success = nftAuction.addGoodsToAuction(1, 1000, 1 days);
        assertEq(success, true);
        vm.stopPrank();
    }

    function test_addGoodsToAuction_notseller() public {
        // TODO: implement test
        vm.startPrank(bidder1);
        vm.expectRevert();
        nftAuction.addGoodsToAuction(1, 1000, 10000);
        vm.stopPrank();
    }

    function test_addGoodsToAuction_existed() public {
        // TODO: implement test
        vm.startPrank(seller);
        bool success = nftAuction.addGoodsToAuction(1, 1000, 10000);
        assertEq(success, true);

        vm.expectRevert();
        nftAuction.addGoodsToAuction(1, 1000, 10000);
        vm.stopPrank();
    }

    function test_addGoodsToAuction_pricegreaterthanzero() public {
        // TODO: implement test
        vm.startPrank(seller);
        vm.expectRevert();
        nftAuction.addGoodsToAuction(1, 0, 10000);
        
        vm.stopPrank();
    }

    function test_bid() public {
        // TODO: implement test
        
        vm.startPrank(bidder1);
        bool success=nftAuction.bid(11,1100);
        assertEq(success, true);
        vm.stopPrank();

        // vm.startPrank(bidder2);
        // success=nftAuction.bid(10,11,1200);
        // assertEq(success, true);
        // vm.stopPrank();

        // vm.startPrank(bidder3);
        // success=nftAuction.bid(10,11,1300);
        // assertEq(success, true);
        // vm.stopPrank();

        // vm.startPrank(seller);
        // (address winner, uint256 price)=nftAuction.getLastBidder(11);
        // assertEq(winner, bidder1);
        // assertEq(price, 1100);
        // vm.stopPrank();
    }

    function test_cancelAuction() public {
        // TODO: implement test
        vm.roll(2000);
        vm.startPrank(seller);
        bool success=nftAuction.sellerWithdraw(11);
        assertEq(success, true);
        vm.stopPrank();
    }

    function test_cancelAuction_notseller() public {
        // TODO: implement test
        vm.roll(2000);
        vm.startPrank(bidder1);
        vm.expectRevert();
        nftAuction.sellerWithdraw(11);  
        vm.stopPrank();
    }

    function test_cancelAuction_inAucting() public {
        // TODO: implement test
        vm.startPrank(bidder1);
        nftAuction.bid(11,1100);
        vm.stopPrank();
        
        vm.roll(2000);
        vm.startPrank(seller);
        vm.expectRevert();
        nftAuction.sellerWithdraw(11);
        vm.stopPrank();
    }
    
    function test_withdraw() public {
        // TODO: implement test
    }
}