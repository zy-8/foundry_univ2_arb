pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "uniswapv2-solc0.8/UniswapV2Factory.sol";
import "uniswapv2-solc0.8/test/WETH9.sol";
import "../src/FlashLoanArbitrage.sol";

contract FlashLoanArbitrageTest is Test {
  FlashLoanArbitrage arbitrage;
  //池子A
  address poolA;
  //池子B
  address poolB;
  WETH9 weth;
  MyToken tokenA;

  function setUp() public {
    //创建两个代币
    tokenA = new MyToken("TokenA", "TKA", 10000 ether);
    weth = new WETH9();

    //创建两个交易对
    poolA = new UniswapV2Factory(address(this)).createPair(address(weth), address(tokenA));

    poolB = new UniswapV2Factory(address(this)).createPair(address(weth), address(tokenA));

    // 为 PoolA 提供流动性：1000 TKA 和 1000 WETH (价格 1:1)
    tokenA.transfer(poolA, 1000 ether);

    weth.deposit{ value: 1000 ether }();
    weth.transfer(poolA, 1000 ether);

    IUniswapV2Pair(poolA).mint(address(this));

    // 为 PoolB 提供流动性：1000 TKA 和 500 WETH (价格 2:1)
    tokenA.transfer(poolB, 1000 ether);

    weth.deposit{ value: 500 ether }();
    weth.transfer(poolB, 500 ether);

    IUniswapV2Pair(poolB).mint(address(this));

    // 获取池子储备量
    (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(poolA).getReserves();
    console.log("PoolA reserves:", reserve0, reserve1);
    (reserve0, reserve1,) = IUniswapV2Pair(poolB).getReserves();
    console.log("PoolB reserves:", reserve0, reserve1);

    // 初始化闪电贷套利合约
    arbitrage = new FlashLoanArbitrage();
  }

  /**
   * @dev 计算最优套利金额和预期利润
   * @return amount 最优套利金额
   * @return profit 预期获得的利润
   */
  function calculateOptimalArbitrage() public view returns (uint256 amount, uint256 profit) {
    // 获取两个池子的储备量
    (uint256 a0, uint256 a1,) = IUniswapV2Pair(poolA).getReserves();
    (uint256 b0, uint256 b1,) = IUniswapV2Pair(poolB).getReserves();

    console.log("Pool Status:");
    console.log("- Pool A (reserves):", a0 / 1e18, a1 / 1e18);
    console.log("- Pool B (reserves):", b0 / 1e18, b1 / 1e18);

    // 计算最优套利金额
    // 使用 Uniswap V2 的价格公式：(x * y) = k
    uint256 k = b0 * b1;
    uint256 numerator = sqrt(uint256(997) ** 2 * k);
    uint256 denominator = 1000;
    amount = ((numerator / denominator) - b0) * 1000 / 997;

    // 计算完整的套利路径：
    // 1. 从池子A借 amount ETH
    // 2. 在池子B用 amount ETH 换 Token
    uint256 tokenReceived = arbitrage._getAmountOut(amount, b0, b1);
    
    // 3. 计算需要还给池子A的 Token 数量（包含 0.3% 手续费）
    uint256 tokenToRepay = arbitrage._getExactAmountIn(amount, a1, a0);

    // 4. 计算实际利润 = 获得的 Token - 需要还的 Token
    if (tokenReceived > tokenToRepay) {
        profit = tokenReceived - tokenToRepay;
    }

    console.log("Arbitrage Analysis:");
    console.log("- Borrow from Pool A:", amount / 1e18, "ETH");
    console.log("- Receive from Pool B:", tokenReceived / 1e18, "Token");
    console.log("- Repay to Pool A:", tokenToRepay / 1e18, "Token");
    console.log("- Expected profit:", profit / 1e18, "Token");
  }

  /**
   * @dev 计算平方根
   */
  function sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
        y = z;
        z = (x / z + z) / 2;
    }
  }

  function testFlashLoanArbitrage() public {
    (uint256 amount, uint256 profit) = calculateOptimalArbitrage();
    
    console.log("Arbitrage Analysis:");
    console.log("- Optimal trade amount:", amount / 1e18, "ETH");
    console.log("- Expected profit:", profit / 1e18, "ETH");

    if (profit > 0) {
        console.log("Executing arbitrage trade...");
        arbitrage.executeArbitrage(poolA, poolB, amount);
    } else {
        console.log("No profitable arbitrage opportunity");
    }

    // 检查最终余额
    console.log("WETH balances:", weth.balanceOf(address(arbitrage)));
    console.log("TokenA balances:", tokenA.balanceOf(address(arbitrage)));
  }
}
