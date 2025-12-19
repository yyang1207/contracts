// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Weth is ReentrancyGuard {
    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public pendingWithdrawals;
    
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event WithdrawalRequested(address indexed src, uint256 wad);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();
    error WithdrawalFailed();
    error Nopendingwithdrawal();
    error ETHTransferFailed();

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
 
    function withdraw(uint256 wad) external nonReentrant {
        if(balanceOf[msg.sender] < wad) revert InsufficientBalance();
        balanceOf[msg.sender] -= wad;

        pendingWithdrawals[msg.sender] += wad;
        emit WithdrawalRequested(msg.sender, wad); 
    }

    function claimWithdrawal() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if(amount == 0) revert Nopendingwithdrawal();
        
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        if(!success) revert ETHTransferFailed();
        emit Withdrawal(msg.sender, amount); 
    }

    function balances(address account) public view returns (uint256) {
        return balanceOf[account];
    }

    function transfer(address dst, uint256 wad) external nonReentrant returns (bool) {
        if(balanceOf[msg.sender] < wad) revert InsufficientBalance();
        balanceOf[msg.sender] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(msg.sender, dst, wad);
        return true;
    }

    function approve(address spender, uint256 value) external nonReentrant returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address src, address dst, uint256 wad) external nonReentrant returns (bool) {
        if(balanceOf[src] < wad) revert InsufficientBalance();
        if(allowance[src][msg.sender] < wad) revert InsufficientAllowance();
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        allowance[src][msg.sender] -= wad;
        emit Transfer(src, dst, wad);
        return true;
    }
}