// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyToken.sol";
import "uniswapv2-solc0.8/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title 闪电贷套利合约
 * @notice 这个合约用于在 Uniswap V2 上执行闪电贷套利
 * @dev 套利步骤：
 * 1. 从 PoolA 借出 token0
 * 2. 在 PoolB 中用 token0 换取 token1
 * 3. 用获得的 token1 偿还 PoolA 的贷款
 * 4. 保留差价作为利润
 *
 * 示例：
 * PoolA: ETH-USDT 池 (1 ETH = 2000 USDT)
 * PoolB: ETH-USDT 池 (1 ETH = 2100 USDT)
 *
 * 操作流程：
 * 1. 从 PoolA 借 1 ETH
 * 2. 在 PoolB 中用 1 ETH 换得 2100 USDT
 * 3. 还给 PoolA 2000 USDT
 * 4. 获利 100 USDT
 */
contract FlashLoanArbitrage {
  constructor() { }

  /**
   * @notice 开始套利操作
   * @param poolA 第一个交易池地址（借出闪电贷的池子）
   * @param poolB 第二个交易池地址（用于套利的池子）
   * @param amountA 借出的 token0 数量
   *
   * 示例调用：
   * executeArbitrage(
   *     0x123...（ETH-USDT池A地址）,
   *     0x456...（ETH-USDT池B地址）,
   *     1000000000000000000  // 借 1 ETH
   * )
   */
  function executeArbitrage(address poolA, address poolB, uint256 amountA) external {
    IUniswapV2Pair(poolA).swap(amountA, 0, address(this), abi.encode(poolA, poolB));
  }

  /**
   * @notice Uniswap V2 闪电贷回调函数
   * @dev 这个函数会在收到闪电贷后自动被调用
   * @param sender 交易发起者
   * @param amount0 收到的 token0 数量
   * @param amount1 收到的 token1 数量
   * @param data 附加数据
   */
  function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
    (address poolA, address poolB) = abi.decode(data, (address, address));
    require(msg.sender == poolA && sender == address(this), "Invalid caller or sender");

    address token0 = IUniswapV2Pair(poolA).token0();
    address token1 = IUniswapV2Pair(poolA).token1();

    (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(poolB).getReserves();
    uint256 amountOut = _getAmountOut(amount0, reserve0, reserve1);
    // 在 PoolB 中进行套利交易
    IERC20(token0).transfer(poolB, amount0);
    IUniswapV2Pair(poolB).swap(0, amountOut, address(this), "");


    // 计算需要偿还的金额（包含 0.3% 手续费）
    (uint256 reserveA, uint256 reserveB,) = IUniswapV2Pair(poolA).getReserves();
    uint256 amountToRepay = _getExactAmountIn(amount0, reserveA, reserveB);
    // 检查并偿还闪电贷
    require(IERC20(token1).balanceOf(address(this)) >= amountToRepay, "Insufficient balance for repayment");
    IERC20(token1).transfer(poolA, amountToRepay);
  }

  /**
   * @notice 计算交易输出金额
   * @dev 使用 Uniswap V2 的价格公式：(x * y) = k
   * @param amountIn 输入金额
   * @param reserveIn 输入代币储备量
   * @param reserveOut 输出代币储备量
   * @return amountOut 可以获得的输出金额
   */
  function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
    require(amountIn > 0, "Insufficient input amount");
    require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

    // 计算扣除 0.3% 手续费后的实际输入金额
    uint256 amountInWithFee = amountIn * 997;
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = reserveIn * 1000 + amountInWithFee;

    return numerator / denominator;
  }

  
  /**
   * @notice 计算需要偿还的闪电贷金额
   * @dev 用于计算需要偿还的闪电贷金额
   * @param amountOut 想要借出的金额
   * @param reserveIn 输入代币储备量
   * @param reserveOut 输出代币储备量
   * @return amountIn 需要偿还的金额（包含 0.3% 手续费）
   */
  function _getExactAmountIn(
    uint256 amountOut, // Δx
    uint256 reserveIn, // y
    uint256 reserveOut // x
  ) public pure returns (uint256 amountIn) {
    require(amountOut < reserveOut, "INSUFFICIENT_LIQUIDITY");
    uint256 numerator = reserveIn * amountOut * 1000;
    uint256 denominator = (reserveOut - amountOut) * 997;
    amountIn = numerator / denominator + 1; // 向上取整，避免精度亏损
  }
}
