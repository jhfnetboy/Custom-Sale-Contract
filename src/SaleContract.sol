// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SaleContract
 * @author Mycelium Protocol
 * @notice This contract manages the initial sale of GToken.
 * It uses a multi-stage linear price curve to sell a fixed supply of tokens.
 * Access is controlled by an off-chain whitelist mechanism via EIP-712 signatures.
 */
contract SaleContract is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    // =============================================================
    //                           STATE
    // =============================================================

    ERC20 public immutable G_TOKEN;
    address public treasury;

    uint256 public tokensSold;
    uint256 public totalTokensForSale;

    // Mapping to prevent a user from buying more than once
    mapping(address => bool) public hasBought;

    // Off-chain signature verifier address
    address public whitelistVerifier;

    // --- Slope-Driven Price Curve Parameters ---
    uint256 public constant PRECISION = 1e36;
    uint256 public constant INITIAL_PRICE_USD = 1_000_000; // $1.00

    // Slopes are defined as USD price increase (6 decimals) per 10,000 GTokens (1e18 decimals)
    // slope = (price_increase * PRECISION) / (token_amount)
    uint256 public constant STAGE1_SLOPE = (25_000 * PRECISION) / (10_000 * 1e18);   // $0.025 per 10k tokens
    uint256 public constant STAGE2_SLOPE = (50_000 * PRECISION) / (10_000 * 1e18);   // $0.05 per 10k tokens
    uint256 public constant STAGE3_SLOPE = (30_000 * PRECISION) / (10_000 * 1e18);   // $0.03 per 10k tokens

    // These thresholds define the token sale stages.
    uint256 public constant STAGE1_TOKEN_LIMIT = 210_000 * 1e18;
    uint256 public constant STAGE2_TOKEN_LIMIT = 630_000 * 1e18; // 210k + 420k
    uint256 public constant TOTAL_TOKEN_LIMIT = 1_050_000 * 1e18; // Stage 1 + 2 + 3

    // Base prices for each stage are now calculated based on the slopes of previous stages
    uint256 public constant STAGE2_BASE_PRICE_USD = INITIAL_PRICE_USD + (STAGE1_TOKEN_LIMIT * STAGE1_SLOPE) / PRECISION;
    uint256 public constant STAGE3_BASE_PRICE_USD = STAGE2_BASE_PRICE_USD + ((STAGE2_TOKEN_LIMIT - STAGE1_TOKEN_LIMIT) * STAGE2_SLOPE) / PRECISION;
    uint256 public constant CEILING_PRICE_USD = STAGE3_BASE_PRICE_USD + ((TOTAL_TOKEN_LIMIT - STAGE2_TOKEN_LIMIT) * STAGE3_SLOPE) / PRECISION;

    // =============================================================
    //                          EVENTS
    // =============================================================

    event TokensPurchased(address indexed buyer, uint256 gTokenAmount, uint256 usdValue);
    event WhitelistVerifierUpdated(address indexed newVerifier);
    event TreasuryUpdated(address indexed newTreasury);

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(address _gTokenAddress, address _initialTreasury, address _initialOwner) Ownable(_initialOwner) {
        G_TOKEN = ERC20(_gTokenAddress);
        treasury = _initialTreasury;
        totalTokensForSale = TOTAL_TOKEN_LIMIT;
    }

    // =============================================================
    //                      PRICE CALCULATION
    // =============================================================

    /**
     * @notice Calculates the current price of one GToken in USD (with 6 decimals).
     */
    function getCurrentPriceUSD() public view returns (uint256) {
        uint256 sold = tokensSold;

        if (sold >= TOTAL_TOKEN_LIMIT) {
            return CEILING_PRICE_USD; // Return calculated ceiling price
        }

        if (sold < STAGE1_TOKEN_LIMIT) {
            return INITIAL_PRICE_USD + (sold * STAGE1_SLOPE) / PRECISION;
        } else if (sold < STAGE2_TOKEN_LIMIT) {
            uint256 soldInStage2 = sold - STAGE1_TOKEN_LIMIT;
            return STAGE2_BASE_PRICE_USD + (soldInStage2 * STAGE2_SLOPE) / PRECISION;
        } else {
            uint256 soldInStage3 = sold - STAGE2_TOKEN_LIMIT;
            return STAGE3_BASE_PRICE_USD + (soldInStage3 * STAGE3_SLOPE) / PRECISION;
        }
    }

    // =============================================================
    //                       PURCHASE LOGIC
    // =============================================================

    /**
     * @notice Main function to purchase GTokens.
     * @param _usdAmount The amount in USD (with 6 decimals) the user wants to spend.
     * @param _paymentToken The address of the ERC20 token to pay with (e.g., USDC, USDT, WBTC).
     *
     * TODO: Implement the full logic for the function.
     */
    function buyTokens(uint256 _usdAmount, address _paymentToken, bytes calldata /* _signature */)
        external
        payable
        nonReentrant
    {
        // 1. Check if sale is active and has not ended
        require(tokensSold < totalTokensForSale, "Sale has ended");

        // 2. Check against multiple buys
        require(!hasBought[msg.sender], "Address has already bought tokens");

        // 3. Verify the signature from the off-chain service
        // TODO: Implement EIP-712 signature verification.
        // The signature should verify the buyer (msg.sender) and the max USD amount they are allowed to spend.
        // require(verifySignature(msg.sender, _usdAmount, _signature), "Invalid signature");

        // 4. Calculate GToken amount to be received
        // TODO: For simplicity, this example uses current price. A real implementation
        // should integrate over the curve for large purchases.
        uint256 currentPrice = getCurrentPriceUSD();
        uint256 gTokenAmount = (_usdAmount * 1e18) / currentPrice;
        require(tokensSold + gTokenAmount <= totalTokensForSale, "Purchase exceeds available tokens");

        // 5. Handle payment
        // TODO: Use a Chainlink price feed to convert _usdAmount to the equivalent
        // amount of _paymentToken. For ETH, use msg.value.
        // For this placeholder, we assume _paymentToken is USDC (6 decimals) and 1:1 with USD.
        ERC20 paymentERC20 = ERC20(_paymentToken);
        paymentERC20.safeTransferFrom(msg.sender, treasury, _usdAmount);

        // 6. Update state
        tokensSold += gTokenAmount;
        hasBought[msg.sender] = true;

        // 7. Transfer GTokens
        G_TOKEN.safeTransfer(msg.sender, gTokenAmount);

        emit TokensPurchased(msg.sender, gTokenAmount, _usdAmount);
    }


    // =============================================================
    //                        ADMIN FUNCTIONS
    // =============================================================

    function setWhitelistVerifier(address _newVerifier) external onlyOwner {
        whitelistVerifier = _newVerifier;
        emit WhitelistVerifierUpdated(_newVerifier);
    }

    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Zero address");
        treasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

    /**
     * @notice In case any GTokens remain unsold after the sale period,
     * the owner can withdraw them back to the treasury.
     */
    function withdrawUnsoldTokens() external onlyOwner {
        uint256 remaining = G_TOKEN.balanceOf(address(this));
        if (remaining > 0) {
            G_TOKEN.safeTransfer(treasury, remaining);
        }
    }
}
