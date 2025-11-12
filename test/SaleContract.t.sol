// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SaleContract} from "../src/SaleContract.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Concrete, mintable ERC20 for testing GToken
contract MockGToken is ERC20 {
    constructor() ERC20("GToken", "GT") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Concrete, mintable ERC20 with 6 decimals for testing USDC
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract SaleContractTest is Test {
    SaleContract public saleContract;
    MockGToken public gToken; // Changed from ERC20 to MockGToken
    MockUSDC public usdc;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public verifier = makeAddr("verifier");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Constants from SaleContract for easier testing
    uint256 public constant STAGE1_TOKEN_LIMIT = 210_000 * 1e18;
    uint256 public constant STAGE2_TOKEN_LIMIT = 630_000 * 1e18;
    uint256 public constant TOTAL_TOKEN_LIMIT = 1_050_000 * 1e18;

    function setUp() public {
        // Deploy mock tokens
        gToken = new MockGToken(); // Correctly instantiate the concrete contract
        usdc = new MockUSDC();

        // Deploy the SaleContract
        vm.startPrank(owner);
        saleContract = new SaleContract(address(gToken), treasury, owner);
        saleContract.setWhitelistVerifier(verifier);
        vm.stopPrank();

        // Fund the sale contract with tokens to sell
        gToken.mint(address(saleContract), TOTAL_TOKEN_LIMIT); // This will now work

        // Fund users with USDC
        usdc.mint(user1, 1_000_000 * 1e6); // 1M USDC
        usdc.mint(user2, 1_000_000 * 1e6); // 1M USDC
    }

    // =============================================
    // SECTION 1: Initial State & Price Calculation
    // =============================================

    function test_InitialState() public {
        assertEq(saleContract.owner(), owner);
        assertEq(address(saleContract.G_TOKEN()), address(gToken));
        assertEq(saleContract.treasury(), treasury);
        assertEq(saleContract.whitelistVerifier(), verifier);
        assertEq(saleContract.tokensSold(), 0);
        assertEq(gToken.balanceOf(address(saleContract)), TOTAL_TOKEN_LIMIT);
    }

    function test_Price_AtStart() public {
        assertEq(saleContract.getCurrentPriceUSD(), 1_000_000); // .00
    }

    function test_Price_InStage1() public {
        setTokensSold(100_000 * 1e18); // Manually set state for testing
        uint256 expectedPrice = 1_000_000 + (100_000 * 1e18 * saleContract.STAGE1_SLOPE()) / 1e18;
        assertEq(saleContract.getCurrentPriceUSD(), expectedPrice);
    }

    function test_Price_AtBoundary1To2() public {
        setTokensSold(STAGE1_TOKEN_LIMIT);
        assertEq(saleContract.getCurrentPriceUSD(), 1_500_000); // .50
    }

    function test_Price_InStage2() public {
        uint256 soldInStage2 = 50_000 * 1e18;
        setTokensSold(STAGE1_TOKEN_LIMIT + soldInStage2);
        uint256 expectedPrice = 1_500_000 + (soldInStage2 * saleContract.STAGE2_SLOPE()) / 1e18;
        assertEq(saleContract.getCurrentPriceUSD(), expectedPrice);
    }

    function test_Price_AtBoundary2To3() public {
        setTokensSold(STAGE2_TOKEN_LIMIT);
        assertEq(saleContract.getCurrentPriceUSD(), 2_500_000); // $2.50
    }

    function test_Price_InStage3() public {
        uint256 soldInStage3 = 100_000 * 1e18;
        setTokensSold(STAGE2_TOKEN_LIMIT + soldInStage3);
        uint256 expectedPrice = 2_500_000 + (soldInStage3 * saleContract.STAGE3_SLOPE()) / 1e18;
        assertEq(saleContract.getCurrentPriceUSD(), expectedPrice);
    }

    function test_Price_AtSaleEnd() public {
        setTokensSold(TOTAL_TOKEN_LIMIT);
        assertEq(saleContract.getCurrentPriceUSD(), 3_000_000); // $3.00
    }

    // =============================================
    // SECTION 2: Purchase Logic
    // =============================================

    function test_BuyTokens_Success_Simple() public {
        // This test will pass with the current placeholder logic in SaleContract
        uint256 usdAmount = 3000 * 1e6; // $3000
        uint256 expectedGTokenAmount = (usdAmount * 1e18) / saleContract.getCurrentPriceUSD();

        // --- Test Setup ---
        // 1. Add a helper function in SaleContract to bypass signature for testing
        // saleContract.setSignatureBypass(true);
        // 2. For now, we assume the signature is valid.

        // --- Execution ---
        vm.startPrank(user1);
        usdc.approve(address(saleContract), usdAmount);
        // For now, signature is bytes("") as it's not implemented
        saleContract.buyTokens(usdAmount, address(usdc), "");
        vm.stopPrank();

        // --- Assertions ---
        assertEq(saleContract.tokensSold(), expectedGTokenAmount);
        assertEq(gToken.balanceOf(user1), expectedGTokenAmount);
        assertEq(usdc.balanceOf(treasury), usdAmount);
        assertTrue(saleContract.hasBought(user1));
    }

    function test_Revert_When_DoubleBuy() public {
        uint256 usdAmount = 100 * 1e6;

        // First purchase
        vm.startPrank(user1);
        usdc.approve(address(saleContract), usdAmount * 2);
        saleContract.buyTokens(usdAmount, address(usdc), "");

        // Second purchase should fail
        vm.expectRevert("Address has already bought tokens");
        saleContract.buyTokens(usdAmount, address(usdc), "");
        vm.stopPrank();
    }

    function test_Revert_When_SaleEnded() public {
        setTokensSold(TOTAL_TOKEN_LIMIT); // Simulate sold out

        vm.startPrank(user2);
        usdc.approve(address(saleContract), 100 * 1e6);
        vm.expectRevert("Sale has ended");
        saleContract.buyTokens(100 * 1e6, address(usdc), "");
        vm.stopPrank();
    }

    // =============================================
    // SECTION 3: Admin Functions
    // =============================================

    function test_Admin_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(owner);
        saleContract.setTreasury(newTreasury);
        assertEq(saleContract.treasury(), newTreasury);
    }

    function test_Revert_When_NonOwnerSetsTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        saleContract.setTreasury(newTreasury);
    }

    function test_Admin_WithdrawUnsold() public {
        // No unsold tokens yet
        vm.prank(owner);
        saleContract.withdrawUnsoldTokens(); // Should do nothing, not revert

        // Manually send some GToken to the contract to simulate "unsold"
        gToken.mint(address(saleContract), 1000 * 1e18);
        uint256 ownerBalanceBefore = gToken.balanceOf(treasury);
        saleContract.withdrawUnsoldTokens();
        assertEq(gToken.balanceOf(treasury), ownerBalanceBefore + 1000 * 1e18);
    }

    // Helper function to allow `setTokensSold` for testing
    function setTokensSold(uint256 amount) internal {
        bytes32 slot = keccak256("tokensSold");
        vm.store(address(saleContract), slot, bytes32(amount));
    }
}
