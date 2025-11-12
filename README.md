# Foundry template

This is a template for a Foundry project.

## Installation

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install [user]/[repo]
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test
```

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol -f [network]
```

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```

-------

这个 Foundry 模板的所有核心安全隐患和配置问题都已解决：
1.  **危险的 `solmate` 库** -> 已替换为社区维护版 ✅
2.  **缺失 `OpenZeppelin`** -> 已安装 ✅
3.  **浮动的 Solidity 版本** -> 已在 `foundry.toml` 中固定 ✅
4.  **过高的优化器设置** -> 已在 `foundry.toml` 中调整 ✅

“分段线性价格曲线”销售合约的完整框架。它包含了所有关键的状态变量、价格计算逻辑和管理员功能。其中一些核心逻辑（如签名验证、多币种支付）留有 `TODO` 注释，方便您后续填充。

为了让这个项目成为一个完整的、可测试、可部署的专业项目，我还将为您创建对应的**测试合约**和**部署脚本**的初始框架。

1.  **测试合约 (`test/SaleContract.t.sol`)**: 用于验证您合约逻辑的正确性。
2.  **部署脚本 (`script/DeploySaleContract.s.sol`)**: 用于在未来将合约部署到测试网或主网。
