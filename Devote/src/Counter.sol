// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

contract Counter {
    uint256 private number;

    function setNumber(uint256 newNumber) external  {
        number = newNumber;
    }

    function increment() external {
        number++;
    }
    
    function getNumber() external view returns(uint256)
    {
	    return (number);
    }
}
