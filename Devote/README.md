## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### 单元测试

```shell
$ forge test --match-path "test/MyDevote.t.sol"


#分叉测试
forge test --match-path "test/MyDevote.t.sol" --fork-url https://rpc.hoodi.ethpandaops.io --fork-block-number 1894260 -vvvv
```

### 代码覆盖率

```shell
$ forge coverage --match-path "contracts/MyDevote.sol"
```

### vm作弊码

#### 1. 异常

vm.expectRevert();
vm.expectRevert(bytes("id not zero"));

#### 2. blocknumber

vm.roll(1500);

#### 3. 指定msg.sender

vm.startPrank(user);
vm.stopPrank();

#### 4. 添加余额

vm.deal(user, 10);

### slither

基本用法

```shell
$ slither src/MyDevote.sol
```

### mythril

基本用法

```shell
$ myth -x src/MyDevote.sol
```

使用配置文件

```shell
myth analyze src/MyDevote.sol --config myth-config.json -o json > myth-report.json
```


