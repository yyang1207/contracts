// SPDX-License-Identifier: MIT 
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MyDevote} from "../src/MyDevote.sol";
contract MyDevoteTest is Test
{
    MyDevote private myDevote;

    function setUp() public {
        myDevote = new MyDevote();
        initproposal(1);
        initproposal(2);
        initproposal(3);

    }

    function initproposal(uint256 pid) private 
    {
        uint8[] memory options= new uint8[](3);
        options[0]=1;
        options[1]=2;   
        options[2]=3;

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);
    }

    function test_createProposal() public {
        uint256 pid=12;
        uint8[] memory options= new uint8[](3);
        options[0]=1;
        options[1]=2;   
        options[2]=3;

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);

        (uint256 id, string memory title, string memory description,address user, uint8[] memory option1,uint256 endblock) = myDevote.getProposal(pid);
        assertEq(id, pid);
        assertEq(title, "Test Proposal");
        assertEq(description, "This is a test proposal");
        assertEq(endblock, 1000);
        for(uint i=0;i<options.length;i++){
            assertEq(option1[i], options[i]);
        }
        assertEq(user, address(this));
    }

    function test_createProposal_id_zero() public 
    {
        uint256 pid=0;
        uint8[] memory options= new uint8[](3);
        options[0]=1;
        options[1]=2;   
        options[2]=3;

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;

        //抛出异常
        vm.expectRevert();
        //vm.expectRevert(bytes("id not zero"));
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);


        // (uint256 id, string memory title, string memory description,address user, uint8[] memory option1,uint256 endblock) = myDevote.getProposal(pid);
        // assertEq(id, pid);
        // assertEq(title, "Test Proposal");
        // assertEq(description, "This is a test proposal");
        // assertEq(endblock, 1000);
        // for(uint i=0;i<options.length;i++){
        //     assertEq(option1[i], options[i]);
        // }
        // assertEq(user, address(this));
    }

    function test_createProposal_options_more() public {
        uint256 pid=12;
        uint8[] memory options= new uint8[](15);
        options[0]=1;
        options[1]=2;   
        options[2]=1;
        options[3]=1;
        options[4]=1;
        options[5]=1;
        options[6]=1;
        options[7]=1;
        options[8]=1;
        options[9]=1;
        options[10]=1;
        options[11]=1;
        options[12]=1;
        options[13]=1;
        options[14]=1;

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;

        //抛出异常
        vm.expectRevert(bytes("invalid options"));
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);
    }

    function test_createProposal_options_empty() public {
        uint256 pid=12;
        uint8[] memory options= new uint8[](0);

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;

        //抛出异常
        vm.expectRevert(bytes("invalid options"));
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);
    }

    function test_createProposal_options_duplicate() public {
        uint256 pid=12;
        uint8[] memory options= new uint8[](3);
        options[0]=1;
        options[1]=2;   
        options[2]=1;

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;

        //抛出异常
        vm.expectRevert(bytes("Duplicate"));
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);
    }

    function test_createProposal_endblock() public {
        uint256 pid=12;
        uint8[] memory options= new uint8[](3);
        options[0]=1;
        options[1]=2;   
        options[2]=3;

        address[] memory users= new address[](4);
        users[0]=address(0x1234);
        users[1]=address(0x5678);
        users[2]=address(0x9abc);
        users[3]=address(0xdeff);
        uint256[] memory balances= new uint256[](4);
        balances[0]=1000;
        balances[1]=2000;
        balances[2]=3000;
        balances[3]=4000;

        vm.roll(1500);
        vm.expectRevert(bytes("end block must gt current block"));
        myDevote.createProposal(pid,"Test Proposal", "This is a test proposal",options,1000,users,balances);
    }

    function test_getProposal() view  public 
    {
        (uint256 id, string memory title, string memory description,address user, ,uint256 endblock) = myDevote.getProposal(1);
        assertEq(id, 1);
        assertEq(title, "Test Proposal");
        assertEq(description, "This is a test proposal");
        assertEq(endblock, 1000);
        assertEq(user, address(this));
    }

    function test_getProposal_notzero()  public 
    {
        vm.expectRevert(bytes("id not zero"));
        myDevote.getProposal(0);
    }

    function test_getProposal_notexists()  public 
    {
        vm.expectRevert(bytes("Proposal not exist"));
        myDevote.getProposal(5);
    }

    function test_addDevote() public 
    {
        vote(address(0x1234),1,1);
        vote(address(0x5678),1,2);
        vote(address(0x9abc),1,3);
        vote(address(0xdeff),1,1);
    }

    function test_addDevote_notzero() public 
    {
        address user=address(0x1234);
        vm.startPrank(user);
        vm.expectRevert(bytes("id not zero"));
        myDevote.addDevote(0,1);
        vm.stopPrank();
    }

    function test_addDevote_invaliduser() public 
    {
        address user=address(0xff12);
        vm.startPrank(user);
        vm.expectRevert(bytes("voter balance must gt 0"));
        myDevote.addDevote(1,2);
        vm.stopPrank();
    }

    function test_addDevote_voted() public 
    {
        address user=address(0x1234);
        vm.startPrank(user);
        myDevote.addDevote(1,2);

        vm.expectRevert(bytes("you have voted"));
        myDevote.addDevote(1,1);
        vm.stopPrank();
    }

    function test_addDevote_finished() public 
    {
        address user=address(0x1234);
        vm.roll(1500);
        vm.startPrank(user);
        vm.expectRevert(bytes("vote has finished"));
        myDevote.addDevote(1,2);
        vm.stopPrank();
    }

    function test_addDevote_notexists() public 
    {
        address user=address(0x1234);
        vm.startPrank(user);
        vm.expectRevert(bytes("Proposal not exist"));
        myDevote.addDevote(5,2);
        vm.stopPrank();
    }

    function test_addDevote_invalid_option() public 
    {
        address user=address(0x1234);
        vm.startPrank(user);
        vm.expectRevert(bytes("invalid option"));
        myDevote.addDevote(1,8);
        vm.stopPrank();
    }

    function vote(address user, uint256 pid, uint8 option) private
    {
        vm.startPrank(user);
        myDevote.addDevote(pid,option);

        uint8 option1= myDevote.getDevote(1);
        assertEq(option, option1);
        vm.stopPrank();
    }

    function test_getdevote() public 
    {
        address user=address(0x1234);
        vote(user,1,1);
        vm.startPrank(user);
        uint8 option1= myDevote.getDevote(1);
        assertEq(option1, 1);
        vm.stopPrank();
    }

    function test_getdevote_proposal_not_zero() public 
    {
        vm.expectRevert(bytes("id not zero"));
        //test not vote
        myDevote.getDevote(0);
    }

    function test_getdevote_proposal_not_exist() public 
    {
        vm.expectRevert(bytes("Proposal not exist"));
        //test not vote
        myDevote.getDevote(10);
    }

    function test_getresult() public 
    {
        vm.roll(10);
        vote(address(0x1234),1,1);

        vm.roll(11);
        vote(address(0x5678),1,2);

        vm.roll(15);
        vote(address(0x9abc),1,3);

        vm.roll(36);
        vote(address(0xdeff),1,1);

        vm.roll(11000);
        (, uint256[] memory voteCounts)= myDevote.getVoteResults(1);
        
        assertEq(voteCounts[0], 5000);  
        assertEq(voteCounts[1], 2000);  
        assertEq(voteCounts[2], 3000);
    }

    function test_getresult_notzero() public 
    {
        vm.roll(110);
        vm.expectRevert(bytes("id not zero"));
        myDevote.getVoteResults(0);
    }

    function test_getresult_notexists() public 
    {
        vm.roll(110);
        vm.expectRevert(bytes("Proposal not exist"));
        myDevote.getVoteResults(10);
    }

    
    function test_getresult_notfinished() public 
    {
        vm.roll(110);
        vm.expectRevert(bytes("wait vote finished"));
        myDevote.getVoteResults(1);
    }
}