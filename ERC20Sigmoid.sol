// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Sigmoid is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18; // 10 billion tokens

    // Sigmoid curve parameters
    uint256 public constant PMAX = 0.01 ether; // Max price (adjust as needed)
    uint256 public constant B = 5; // Controls steepness of curve
    uint256 public constant C = 5_000_000_000 * 10**18; // Midpoint (half supply)

    uint256 public reservePool;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    function sigmoid(uint256 supply) public pure returns (uint256) {
        int256 x = int256(supply - C) / int256(10**18);
        int256 exponent = -int256(B) * x;

        // Approximate e^(-B * x) using Taylor expansion (avoid floating point)
        int256 expValue = (1e18 * 1e18) / (1e18 + expTaylorApproximation(exponent));

        return (PMAX * 1e18) / (1e18 + uint256(expValue));
    }

    function expTaylorApproximation(int256 x) internal pure returns (int256) {
        int256 term = 1e18;
        int256 sum = 1e18;
        for (uint8 i = 1; i < 10; i++) {
            // Multiply `i` by `1e18` and cast the result to `int256`
            term = (term * x) / (int256(uint256(i)) * 1e18);
            sum += term;
        }
        return sum;
    }

    function calculateCurrentPrice() public view returns (uint256) {
        return sigmoid(totalSupply());
    }

    function getTokenAmount(uint256 etherAmount) public view returns (uint256) {
        require(etherAmount > 0, "Amount must be greater than 0");

        uint256 currentPrice = calculateCurrentPrice();
        return (etherAmount * 10**18) / currentPrice;
    }

    function buyTokens() external payable {
        require(msg.value > 0, "Must send ETH to buy tokens");

        uint256 tokensToBuy = getTokenAmount(msg.value);
        require(totalSupply() + tokensToBuy <= MAX_SUPPLY, "Would exceed max supply");

        reservePool += msg.value;
        _mint(msg.sender, tokensToBuy);
    }

    function sellTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 currentPrice = calculateCurrentPrice();
        uint256 ethToReturn = (amount * currentPrice) / 10**18;

        require(ethToReturn <= reservePool, "Not enough ETH in reserve");

        _burn(msg.sender, amount);
        reservePool -= ethToReturn;
        payable(msg.sender).transfer(ethToReturn);
    }

    function getSellValueInEth(uint256 amount) external view returns (uint256) {
        uint256 currentPrice = calculateCurrentPrice();
        return (amount * currentPrice) / 10**18;
    }
}
