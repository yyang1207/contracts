// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFT1155Wrapper is ERC1155, ERC721Holder {
    using Strings for uint256;
    
    // 包装代币ID -> 原始NFT信息
    struct WrappedAsset {
        address contractAddress;
        AssetType assetType;
        bool isWrapped;
        uint256 tokenId;
    }
    
    enum AssetType { ERC721, ERC1155, NATIVE }
    
    mapping(uint256 => WrappedAsset) public wrappedAssets;
    mapping(address => mapping(uint256 => uint256)) public wrapperIdOf;
    
    uint256 private _nextTokenId = 1;
    address public owner;
    
    event AssetWrapped(
        uint256 indexed wrapperTokenId,
        address indexed originalContract,
        uint256 originalTokenId,
        AssetType assetType,
        address indexed wrapper
    );
    
    event AssetUnwrapped(
        uint256 indexed wrapperTokenId,
        address indexed originalContract,
        uint256 originalTokenId,
        address indexed receiver
    );
    
    constructor() ERC1155("") {
        owner = msg.sender;
        _setBaseURI("https://api.wrapper.com/token/");
    }
    
    // 动态URI：根据包装代币ID返回原始NFT的元数据
    function uri(uint256 wrapperTokenId) public view override returns (string memory) {
        require(wrappedAssets[wrapperTokenId].isWrapped, "Token not wrapped");
        
        WrappedAsset memory asset = wrappedAssets[wrapperTokenId];
        
        if (asset.assetType == AssetType.ERC721) {
            // 尝试获取原始NFT的tokenURI
            try IERC721Metadata(asset.contractAddress).tokenURI(asset.tokenId) returns (string memory tokenURI) {
                return tokenURI;
            } catch {
                // 回退到基础URI
                return string(abi.encodePacked(super.uri(wrapperTokenId), wrapperTokenId.toString(), ".json"));
            }
        }
        
        return string(abi.encodePacked(super.uri(wrapperTokenId), wrapperTokenId.toString(), ".json"));
    }
    
    // 包装ERC721 NFT
    function wrapERC721(address nftContract, uint256 tokenId) public returns (uint256) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(wrapperIdOf[nftContract][tokenId] == 0, "Already wrapped");
        
        // 接收NFT
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // 生成唯一包装ID
        uint256 wrapperTokenId = _generateWrapperId(nftContract, tokenId);
        
        // 记录映射
        wrappedAssets[wrapperTokenId] = WrappedAsset({
            contractAddress: nftContract,
            tokenId: tokenId,
            assetType: AssetType.ERC721,
            isWrapped: true
        });
        
        wrapperIdOf[nftContract][tokenId] = wrapperTokenId;
        
        // 铸造包装代币
        _mint(msg.sender, wrapperTokenId, 1, "");
        
        emit AssetWrapped(wrapperTokenId, nftContract, tokenId, AssetType.ERC721, msg.sender);
        return wrapperTokenId;
    }
    
    // 批量包装ERC721
    function batchWrapERC721(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds
    ) external returns (uint256[] memory) {
        require(nftContracts.length == tokenIds.length, "Length mismatch");
        
        uint256[] memory wrapperTokenIds = new uint256[](nftContracts.length);
        
        for (uint256 i = 0; i < nftContracts.length; i++) {
            wrapperTokenIds[i] = wrapERC721(nftContracts[i], tokenIds[i]);
        }
        
        return wrapperTokenIds;
    }
    
    // 解包ERC721
    function unwrapERC721(uint256 wrapperTokenId) external {
        require(balanceOf(msg.sender, wrapperTokenId) >= 1, "Not enough balance");
        
        WrappedAsset memory asset = wrappedAssets[wrapperTokenId];
        require(asset.assetType == AssetType.ERC721, "Not ERC721");
        require(asset.isWrapped, "Already unwrapped");
        
        // 销毁包装代币
        _burn(msg.sender, wrapperTokenId, 1);
        
        // 清理映射
        delete wrappedAssets[wrapperTokenId];
        delete wrapperIdOf[asset.contractAddress][asset.tokenId];
        
        // 返回原始NFT
        IERC721(asset.contractAddress).safeTransferFrom(address(this), msg.sender, asset.tokenId);
        
        emit AssetUnwrapped(wrapperTokenId, asset.contractAddress, asset.tokenId, msg.sender);
    }

    // 允许代币所有者将解包后的原始NFT直接发送给指定地址
    function unwrapTo(uint256 wrapperTokenId, address finalRecipient) external {
        // 1. 关键：验证调用者（拍卖合约）**此刻**拥有该包装代币
        require(balanceOf(msg.sender, wrapperTokenId) == 1, "Caller not owner");

        // 2. 获取原始NFT信息
        WrappedAsset memory asset = wrappedAssets[wrapperTokenId];
        require(asset.isWrapped, "Not wrapped");

        // 3. **先销毁**调用者（拍卖合约）的包装代币
        _burn(msg.sender, wrapperTokenId, 1);

        // 4. 清理存储
        delete wrappedAssets[wrapperTokenId];
        delete wrapperIdOf[asset.contractAddress][asset.tokenId];

        // 5. **核心区别**：将原始NFT转给 `finalRecipient`（中标者），而不是 `msg.sender`
        IERC721(asset.contractAddress).safeTransferFrom(
            address(this), // 从包装合约的托管地址转出
            finalRecipient, // 转给中标者
            asset.tokenId
        );

        emit AssetUnwrapped(wrapperTokenId, asset.contractAddress, asset.tokenId, finalRecipient);
    }
    
    // 生成唯一的包装ID
    function _generateWrapperId(address nftContract, uint256 tokenId) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(nftContract, tokenId, block.timestamp, _nextTokenId++)));
    }
    
    function _setBaseURI(string memory baseURI) internal {
        // 设置基础URI逻辑...
    }
}