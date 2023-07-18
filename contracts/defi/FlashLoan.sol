// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoan {
    mapping(address => uint256) public balances;

    // Fallback function for receiving Ether
    receive() external payable {
        if (msg.value > 0) {
            balances[address(0)] += msg.value;
        }
    }

    // Deposit tokens into the contract
    function depositTokens(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount));
        balances[tokenAddress] += amount;
    }

    // Execute a flash loan
    function executeFlashLoan(address tokenAddress, uint256 amount, address borrower, bytes calldata data) external {
        uint256 initialBalance = balances[tokenAddress];
        require(initialBalance >= amount, "Not enough tokens available for flash loan.");

        // Transfer the tokens to the borrower
        IERC20 token = IERC20(tokenAddress);
        token.transfer(borrower, amount);

        // Call the function on the borrower's contract
        (bool success,) = borrower.call(data);
        require(success, "Flash loan failed.");

        // The borrower should have returned the tokens by now
        require(balances[tokenAddress] >= initialBalance, "Flash loan hasn't been paid back.");
    }
}

contract FlashLoanBorrower_UniswapV2 {
    FlashLoan public flashLoan;
    IUniswapV2Router02 public uniswap;
    address public owner;

    constructor(FlashLoan _flashLoan, IUniswapV2Router02 _uniswap) {
        flashLoan = _flashLoan;
        uniswap = _uniswap;
        owner = msg.sender;
    }

    function executeArbitrage(
        address tokenAddress,
        uint256 amount,
        address[] calldata path
    ) external {
        require(msg.sender == owner, "Only the owner can execute the arbitrage.");

        // Receive the flash loan
        flashLoan.executeFlashLoan(tokenAddress, amount, address(this), "");

        // Perform the arbitrage via Uniswap
        uint256 deadline = block.timestamp + 1;
        IERC20(tokenAddress).approve(address(uniswap), amount);
        uniswap.swapExactTokensForTokens(amount, 0, path, address(this), deadline);

        // Return the tokens to the flash loan contract
        uint256 returnAmount = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(address(flashLoan), returnAmount);
    }
}

contract FlashLoanBorrower_UniswapV3 {
    FlashLoan public flashLoan;
    ISwapRouter public uniswapV3Router;
    address public owner;

    constructor(FlashLoan _flashLoan, ISwapRouter _uniswapV3Router) {
        flashLoan = _flashLoan;
        uniswapV3Router = _uniswapV3Router;
        owner = msg.sender;
    }

    function executeArbitrage(
        address tokenAddress,
        uint256 amount,
        address tokenOut,
        uint24 fee,
        uint160 sqrtPriceLimitX96
    ) external {
        require(msg.sender == owner, "Only the owner can execute the arbitrage.");

        // Receive the flash loan
        flashLoan.executeFlashLoan(tokenAddress, amount, address(this), "");

        // Perform the swap via Uniswap V3
        IERC20(tokenAddress).approve(address(uniswapV3Router), amount);

        uniswapV3Router.exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenAddress,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp + 1,  // very short deadline for flashloan
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        }));

        // Return the tokens to the flash loan contract
        uint256 returnAmount = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(address(flashLoan), returnAmount);
    }
}