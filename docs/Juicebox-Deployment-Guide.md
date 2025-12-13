# Juicebox 部署和配置指南

## 概述

本指南将帮助你在基于Juicebox协议的Custom Sale Contract项目中，完整部署和运行一个Juicebox应用，包括后端合约、前端界面和数据索引服务。

**⚠️ 重要说明**: 本指南专注于使用 **Foundry** 作为开发和部署工具，不使用Hardhat。虽然juice-contracts-v3原始项目使用Hardhat进行部署，但我们使用Foundry进行测试和自定义合约开发。

## 架构组件

- **juice-contracts-v3**: Juicebox核心V3合约
- **juice-interface**: Juicebox前端应用
- **juice-subgraph**: The Graph协议的子图，用于数据索引
- **juice-docs**: 完整的技术文档

## 环境准备

**开发工具选择**: 我们使用 **Foundry** 作为主要的Solidity开发工具链，提供更快的编译速度和更好的开发体验。

### 1. 系统要求

```bash
# Foundry (主要开发工具 - Solidity编译、测试、部署)
curl -L https://foundry.paradigm.xyz | sh
source ~/.bashrc
foundryup

# Node.js和Yarn (前端和subgraph开发)
node --version  # 推荐v18+
npm install -g yarn

# Docker (本地subgraph和数据库开发)
# 下载并安装: https://docs.docker.com/get-docker/

# Git
git --version
```

### 2. 安装依赖

```bash
# 克隆项目 (如果你还没有)
git clone <your-repo-url>
cd Custom-Sale-Contract

# 初始化所有submodules
git submodule update --init --recursive

# 安装Foundry依赖 (lib目录下的所有库)
forge install

# 安装前端依赖 (如果需要运行前端)
cd lib/juice-interface
yarn install
cd ../..

# 安装subgraph依赖 (如果需要部署subgraph)
cd lib/juice-subgraph
yarn install
yarn global add @graphprotocol/graph-cli
cd ../..
```

## 合约部署 (juice-contracts-v3)

### 1. 本地测试环境

```bash
cd lib/juice-contracts-v3

# 运行Foundry测试
forge test

# 运行带详细输出的测试
forge test -vv

# 运行特定测试文件
forge test --match-path forge_tests/TestLaunchProject.sol

# 运行带gas报告的测试
forge test --gas-report
```

### 2. 部署到测试网

```bash
cd lib/juice-contracts-v3

# 设置环境变量 (推荐使用.env文件)
export PRIVATE_KEY=your_private_key_here
export RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

# 或者创建.env文件
echo "PRIVATE_KEY=your_private_key_here" > .env
echo "RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY" >> .env

# 部署到Sepolia测试网
# 注意: juice-contracts-v3使用Hardhat部署脚本，但我们可以用Foundry来测试
# 实际部署可能需要使用现有的部署脚本或创建新的Foundry脚本

# 验证部署结果
forge verify-contract --chain sepolia --etherscan-api-key YOUR_ETHERSCAN_KEY \
  <DEPLOYED_CONTRACT_ADDRESS> \
  contracts/JBController3_1.sol:JBController3_1
```

### 3. 部署到主网

```bash
# 设置主网环境变量
export PRIVATE_KEY=your_mainnet_private_key
export RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# 部署到主网 (谨慎操作，确保所有测试都通过)
# 注意: 需要根据实际部署需求创建或修改部署脚本

# 验证主网合约
forge verify-contract --chain mainnet --etherscan-api-key YOUR_ETHERSCAN_KEY \
  <DEPLOYED_CONTRACT_ADDRESS> \
  contracts/JBController3_1.sol:JBController3_1
```

### 4. 自定义合约部署

对于自定义合约，使用Foundry的标准部署方式：

```bash
# 创建部署脚本 (script/DeployCustom.s.sol)
# 然后运行:
forge script script/DeployCustom.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### 5. Foundry配置说明

在你的项目根目录创建 `foundry.toml` 配置文件：

```toml
[profile.default]
src = 'src'          # 合约源码目录
out = 'out'          # 编译输出目录
libs = ['lib']       # 库文件目录
test = 'test'        # 测试文件目录

# 优化设置
optimizer = true
optimizer_runs = 1000000

# 测试网配置
[profile.sepolia]
eth_rpc_url = "https://sepolia.infura.io/v3/YOUR_INFURA_KEY"

[profile.mainnet]
eth_rpc_url = "https://mainnet.infura.io/v3/YOUR_INFURA_KEY"

# Etherscan验证
[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

### 6. Juicebox合约集成

在你的自定义合约中使用Juicebox：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@juicebox-protocol/juice-contracts-v3/contracts/interfaces/IJBController3_1.sol";
import "@juicebox-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";

contract CustomJuiceboxIntegration {
    IJBController3_1 public controller;
    IJBDirectory public directory;

    constructor(address _controller, address _directory) {
        controller = IJBController3_1(_controller);
        directory = IJBDirectory(_directory);
    }

    function createProject(
        JBProjectMetadata calldata _projectMetadata,
        JBFundingCycleData calldata _data,
        JBFundingCycleMetadata calldata _metadata
    ) external returns (uint256 projectId) {
        return controller.launchProjectFor(
            msg.sender,      // _owner
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp, // _mustStartAtOrAfter
            new JBGroupedSplits[](0), // _groupedSplits
            new JBFundAccessConstraints[](0), // _fundAccessConstraints
            new IJBPaymentTerminal[](0), // _terminals
            "Project created" // _memo
        );
    }
}
```

## Subgraph部署 (juice-subgraph)

### 1. 准备工作

```bash
cd lib/juice-subgraph

# 安装依赖
yarn install

# 全局安装Graph CLI
yarn global add @graphprotocol/graph-cli

# 准备Sepolia网络配置
yarn prep:sepolia

# 生成TypeScript类型
yarn codegen
```

### 2. 本地测试

```bash
# 启动本地Graph节点 (需要Docker)
yarn create-local
yarn deploy-local
```

### 3. 部署到The Graph

```bash
# 认证 (需要API密钥)
graph auth --studio your-deploy-key

# 部署到Sepolia测试网
graph deploy --studio juicebox-sepolia

# 部署到主网
graph deploy --studio juicebox-mainnet
```

## 前端配置和运行 (juice-interface)

### 1. 环境配置

```bash
cd lib/juice-interface

# 复制环境配置文件
cp .example.env .env

# 编辑.env文件，配置以下变量:
```

**.env 配置示例:**

```bash
# Infura配置 (用于连接以太坊网络)
NEXT_PUBLIC_INFURA_ID=your_infura_project_id
NEXT_PUBLIC_INFURA_NETWORK=sepolia

# IPFS配置
INFURA_IPFS_PROJECT_ID=your_ipfs_project_id
INFURA_IPFS_API_SECRET=your_ipfs_api_secret
NEXT_PUBLIC_INFURA_IPFS_HOSTNAME=your_gateway_subdomain

# Subgraph配置 (从Peel团队获取)
NEXT_PUBLIC_SUBGRAPH_URL=https://api.thegraph.com/subgraphs/name/jbx-protocol/juicebox-sepolia

# Supabase配置 (本地开发)
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_JWT_SECRET=your_jwt_secret

# Tenderly配置 (可选，用于交易模拟)
NEXT_PUBLIC_TENDERLY_API_KEY=your_tenderly_api_key
NEXT_PUBLIC_TENDERLY_PROJECT_NAME=your_project_name
NEXT_PUBLIC_TENDERLY_ACCOUNT=your_account_name
```

### 2. 启动Supabase (本地数据库)

```bash
# 启动本地Supabase实例
yarn supabase:start

# 复制输出的环境变量到.env文件
```

### 3. 运行前端应用

```bash
# 开发模式
yarn dev

# 生产构建
yarn build
yarn start

# 代码检查和测试
yarn test
yarn type-check
```

## 完整集成测试

### 1. 创建Juicebox项目

```bash
# 在前端界面中:
# 1. 连接钱包 (MetaMask等)
# 2. 创建新项目
# 3. 配置funding cycle参数
# 4. 部署项目合约
```

### 2. 验证数据流

```bash
# 检查subgraph数据
curl -X POST -H "Content-Type: application/json" \
  -d '{"query": "{projects { id name }}}' \
  $NEXT_PUBLIC_SUBGRAPH_URL

# 检查前端是否正确显示项目数据
# 访问: http://localhost:3000
```

## 定制开发指南

### 1. 合约定制

基于现有的SaleContract.sol，你可以：

```solidity
// 继承Juicebox控制器
import "@juicebox-protocol/juice-contracts-v3/contracts/interfaces/IJBController3_1.sol";

// 自定义项目创建逻辑
contract CustomSaleContract {
    IJBController3_1 public controller;

    function createCustomProject(/* 参数 */) external {
        // 使用Juicebox控制器创建项目
        controller.launchProjectFor(/* ... */);
    }
}
```

### 2. 前端定制

```typescript
// 在juice-interface中添加自定义组件
import { JBProject } from '@juicebox-protocol/juice-interface'

// 自定义项目页面
export default function CustomProjectPage() {
    // 使用Juicebox hooks
    const { project } = useJBProject(projectId)

    return (
        <div>
            {/* 自定义UI */}
            <JBProject project={project} />
        </div>
    )
}
```

### 3. Subgraph扩展

```graphql
# 在schema.graphql中添加自定义字段
type CustomSaleContract @entity {
    id: ID!
    projectId: String!
    customField: String
}
```

## 常见问题

### 合约部署问题

1. **Gas费过高**: 在foundry.toml中调整optimizer设置
2. **合约大小限制**: 使用库合约分离逻辑，或使用`--optimize`标志
3. **部署失败**: 检查RPC URL、私钥和网络配置
4. **验证失败**: 确保构造函数参数正确，检查Etherscan API密钥

### 前端配置问题

1. **Infura连接失败**: 检查API密钥和网络配置
2. **Subgraph数据不显示**: 确认subgraph URL和网络匹配

### Subgraph问题

1. **同步失败**: 检查合约地址和起始区块
2. **查询失败**: 验证GraphQL查询语法

## 生产部署清单

- [ ] 合约已在主网上验证
- [ ] Subgraph已在主网上部署并同步
- [ ] 前端环境变量已正确配置
- [ ] SSL证书已配置
- [ ] 监控和告警已设置
- [ ] 备份策略已实施

## 资源链接

- [Juicebox文档](https://info.juicebox.money/dev/)
- [The Graph文档](https://thegraph.com/docs/)
- [Infura文档](https://docs.infura.io/)
- [Supabase文档](https://supabase.com/docs)
- [Peel Discord](https://discord.gg/akpxJZ5HKR)

---

## 快速开始脚本

创建以下脚本简化开发和部署流程：

### 本地开发环境脚本 (deploy-local.sh)

```bash
#!/bin/bash
echo "🚀 启动Juicebox本地开发环境"

# 启动本地anvil节点 (Foundry的本地测试网)
anvil --host 0.0.0.0 --port 8545 &
ANVIL_PID=$!

# 等待anvil启动
sleep 2

# 运行合约测试
cd lib/juice-contracts-v3
forge test &
TEST_PID=$!

# 启动本地Subgraph (如果需要)
cd ../juice-subgraph
yarn create-local &
SUBGRAPH_PID=$!

# 启动前端
cd ../juice-interface
yarn supabase:start &
SUPABASE_PID=$!
yarn dev &
FRONTEND_PID=$!

echo "✅ 本地环境已启动"
echo "🔗 本地RPC: http://localhost:8545"
echo "📱 前端: http://localhost:3000"
echo "🔗 GraphQL: http://localhost:8000/subgraphs/name/juicebox-local"
echo "按Ctrl+C停止所有服务"

trap "kill $ANVIL_PID $TEST_PID $SUBGRAPH_PID $SUPABASE_PID $FRONTEND_PID" INT
wait
```

### 合约部署脚本 (deploy-testnet.sh)

```bash
#!/bin/bash
echo "🚀 部署到Sepolia测试网"

# 加载环境变量
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# 检查必要变量
if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
    echo "❌ 错误: 请设置PRIVATE_KEY和RPC_URL环境变量"
    exit 1
fi

cd lib/juice-contracts-v3

# 运行测试确保一切正常
echo "🧪 运行测试..."
forge test

if [ $? -ne 0 ]; then
    echo "❌ 测试失败，停止部署"
    exit 1
fi

# 部署合约 (需要根据实际需求创建部署脚本)
echo "📦 部署合约..."
# forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify

echo "✅ 部署完成"
```

### 项目初始化脚本 (setup.sh)

```bash
#!/bin/bash
echo "🔧 设置Juicebox开发环境"

# 检查Foundry
if ! command -v forge &> /dev/null; then
    echo "📦 安装Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi

# 初始化submodules
echo "📥 初始化submodules..."
git submodule update --init --recursive

# 安装依赖
echo "📦 安装Foundry依赖..."
forge install

echo "📦 安装前端依赖..."
cd lib/juice-interface
yarn install
cd ../..

echo "📦 安装subgraph依赖..."
cd lib/juice-subgraph
yarn install
yarn global add @graphprotocol/graph-cli
cd ../..

echo "✅ 设置完成！"
echo "运行 './deploy-local.sh' 启动本地开发环境"
```
