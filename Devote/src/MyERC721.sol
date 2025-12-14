// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;


import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract MyERC721 is ERC721
{
    constructor() ERC721("MyERC721", "ME721") 
    {
        
    }
}