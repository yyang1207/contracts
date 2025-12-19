## 还原包

```bash
forge install
```



## 编译

```bash
forge build
```



## 单元测试

```bash
forge test --match-path test/NftAuctionWithCredit.t.sol
```



## Slither

### 1. 配置文件.slither.config.json

```json
{
    "filter_paths": "node_modules,lib",
    "detectors_to_exclude": ["low-level-calls","different-pragma"]
}
```



### 2. 扫描

```bash
# erc20合约
slither src/Weth.sol --exclude-dependencies --config-file .slither.config.json

#erc721合约
slither src/NftERC20.sol  --exclude-dependencies --config-file .slither.config.json

# 拍卖合约
slither src/NftAuctionWithCredit.sol  --exclude-dependencies --config-file .slither.config.json
```



## myth

分析代码

```bash
myth analyze src/NftAuctionWithCredit.sol
```
