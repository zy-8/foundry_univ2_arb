## 套利原理

1. 从池子 A 借出 Token
2. 在池子 B 中进行交易获取收益
3. 偿还池子 A 的贷款
4. 保留差价作为利润

示例：
- 池子 A：1 ETH = 2000 USDT
- 池子 B：1 ETH = 2100 USDT
- 套利过程：借 1 ETH → 换 2100 USDT → 还 2000 USDT → 获利 100 USDT


Ran 1 test for test/FlashLoanArbitrageTest.t.sol:FlashLoanArbitrageTest
[PASS] testFlashLoanArbitrage() (gas: 252123)
Logs:
  PoolA reserves: 1000000000000000000000 1000000000000000000000
  PoolB reserves: 500000000000000000000 1000000000000000000000
  Pool Status:
  - Pool A (reserves): 1000 1000
  - Pool B (reserves): 500 1000
  Arbitrage Analysis:
  - Borrow from Pool A: 205 WETH
  - Receive from Pool B: 290 Token
  - Repay to Pool A: 259 Token
  - Expected profit: 31 Token
  Arbitrage Analysis:
  - Optimal trade amount: 205 WETH
  - Expected profit: 31 Token
  Executing arbitrage trade...
  WETH balances: 0
  TokenA balances: 31171458077754015461

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 2.88ms (671.21µs CPU time)