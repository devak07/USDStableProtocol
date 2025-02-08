// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {CollateralToken} from "src/CollateralToken.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MockV3AggregatorAltered} from "test/mocks/MockV3AggregatorAltered.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title StabilityEngineTest
 * @dev This contract contains unit tests for the `StabilityEngine` contract.
 * It tests the various deposit and redemption functionalities, ensuring that proper error handling occurs in edge cases,
 * such as insufficient balance or zero amounts, and that the contract behaves as expected in typical scenarios.
 */
contract StabilityEngineTest is Test {
    ///////////////////////////////
    /////////// ERRORS ////////////
    ///////////////////////////////

    error StabilityEngine__InvalidAddress();
    error StabilityEngine__MustBeMoreThanZero();
    error StabilityEngine__TransferFailed();
    error StabilityEngine__InvalidPrice();
    error StabilityEngine__InfufficientBalance();
    error ERC20InsufficientAllowance(address sender, uint256 balance, uint256 needed);

    ///////////////////////////////
    ////// STATE VARIABLES ////////
    ///////////////////////////////

    // Instances of the contracts
    StabilityEngine stabilityEngine;
    CollateralToken collateralToken;

    // Addresses and constants
    address owner;
    address priceFeed;
    uint256 collateralValue;
    address private constant FOUNDRY_DEFAULT_ACCOUNT = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;
    uint256 private constant STARTING_TOKEN_AMOUNT = 100;
    uint256 private constant SENDING_TOKEN_AMOUNT = 10;
    uint256 private constant NEW_PRICE = 1e6;

    uint256 private PRECISION = 1e8;

    address USER_1 = makeAddr("USER_1");

    ///////////////////////////////
    ////////// MODIFIERS //////////
    ///////////////////////////////

    /**
     * @dev Modifier for approving tokens for a user.
     * The user must approve the specified amount of tokens for the `StabilityEngine` contract.
     */
    modifier tokensApprovedForUser() {
        vm.startPrank(USER_1);
        IERC20(address(collateralToken)).approve(owner, SENDING_TOKEN_AMOUNT);
        _;
    }

    /**
     * @dev Modifier for depositing collateral in the `StabilityEngine` contract.
     */
    modifier collateralDeposited() {
        stabilityEngine.depositCollateral(SENDING_TOKEN_AMOUNT);
        _;
    }

    /**
     * @dev Modifier for asserting the user's dollar amount after operations.
     */
    modifier assertionUsd() {
        uint256 usdValue = SENDING_TOKEN_AMOUNT * stabilityEngine.getFullTokenValue();
        assertEq(stabilityEngine.getDollarsAmount(USER_1) * PRECISION, usdValue);
        _;
    }

    /**
     * @dev Modifier for setting the collateral value in the test.
     * Sets the collateral value based on the current price feed and amount of collateral.
     */
    modifier setCollateralValue() {
        collateralValue = stabilityEngine.getFullTokenValue() * SENDING_TOKEN_AMOUNT / PRECISION;
        _;
    }

    ///////////////////////////////
    //////// SETUP FUNCTION ///////
    ///////////////////////////////

    /**
     * @dev Setup function to deploy the required contracts before each test.
     */
    function setUp() external {
        Deploy deploy = new Deploy();
        (stabilityEngine) = deploy.run();
        collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());
        owner = address(stabilityEngine);
        priceFeed = stabilityEngine.getPriceFeedAddress();

        vm.prank(owner);
        collateralToken.mint(USER_1, STARTING_TOKEN_AMOUNT);
    }

    ///////////////////////////////
    /////// TEST FUNCTIONS ////////
    ///////////////////////////////

    /**
     * @dev Test: Deposit collateral with zero amount.
     * It expects a revert with `StabilityEngine__MustBeMoreThanZero` error.
     */
    function testDepositCollateralWithZeroAmount() external {
        vm.expectRevert(StabilityEngine__MustBeMoreThanZero.selector);
        stabilityEngine.depositCollateral(0);
    }

    /**
     * @dev Test: Deposit collateral without enough tokens.
     * It expects a revert with `ERC20InsufficientAllowance` error.
     */
    function testDepositCollateralWithoutEnoughTokens() external {
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, owner, 0, 1));
        stabilityEngine.depositCollateral(1);
    }

    /**
     * @dev Test: Deposit collateral with enough tokens.
     * It ensures the deposit happens correctly, triggers the correct event, and updates balances accordingly.
     */
    function testDepositCollateralWithEnoughTokens() external tokensApprovedForUser setCollateralValue {
        vm.recordLogs();
        stabilityEngine.depositCollateral(SENDING_TOKEN_AMOUNT);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs[3].topics[0], keccak256("CollateralDeposited(address,uint256)"));
        assertEq(stabilityEngine.getDollarsAmount(USER_1), collateralValue);
        assertEq(0, collateralToken.balanceOf(owner));
        assertEq(STARTING_TOKEN_AMOUNT - SENDING_TOKEN_AMOUNT, collateralToken.balanceOf(USER_1));
    }

    /**
     * @dev Test: Redeem collateral with zero amount.
     * It expects a revert with `StabilityEngine__MustBeMoreThanZero` error.
     */
    function testRedeemCollateralWithZeroAmount() external {
        vm.expectRevert(StabilityEngine__MustBeMoreThanZero.selector);
        stabilityEngine.redeemCollateral(0);
    }

    /**
     * @dev Test: Redeem collateral without any collateral deposited.
     * It expects a revert with `StabilityEngine__InfufficientBalance` error.
     */
    function testRedeemCollateralWithoutCollateralDeposited() external {
        vm.expectRevert(StabilityEngine__InfufficientBalance.selector);
        stabilityEngine.redeemCollateral(1);
    }

    /**
     * @dev Test: Redeem collateral with too much collateral.
     * It expects a revert with `StabilityEngine__InfufficientBalance` error.
     */
    function testRedeemCollateralWithTooMuchCollateral()
        external
        tokensApprovedForUser
        collateralDeposited
        setCollateralValue
    {
        vm.expectRevert(StabilityEngine__InfufficientBalance.selector);
        stabilityEngine.redeemCollateral(collateralValue + 1);
    }

    /**
     * @dev Test: Redeem collateral with enough collateral deposited.
     * It ensures the redeem operation works, triggers the correct event, and updates balances accordingly.
     */
    function testRedeemCollateralWithDepositEnoughCollateral()
        external
        tokensApprovedForUser
        collateralDeposited
        assertionUsd
        setCollateralValue
    {
        vm.recordLogs();
        stabilityEngine.redeemCollateral(collateralValue);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs[2].topics[0], keccak256("CollateralRedeemed(address,uint256)"));
        assertEq(stabilityEngine.getDollarsAmount(USER_1), 0);
        assertEq(STARTING_TOKEN_AMOUNT, collateralToken.balanceOf(USER_1));
    }

    function testGetTenTokens() external {
        vm.startPrank(USER_1);
        stabilityEngine.getTenTokens();

        assertEq(collateralToken.balanceOf(USER_1), STARTING_TOKEN_AMOUNT + 10);
    }

    /**
     * @dev Test: Full functionality of the `StabilityEngine`.
     * It tests the entire flow of depositing collateral, updating the price feed, and redeeming collateral, ensuring everything works together.
     */
    function testFullFunctionality()
        external
        tokensApprovedForUser
        collateralDeposited
        assertionUsd
        setCollateralValue
    {
        vm.stopPrank();
        uint256 startingTokens = collateralToken.balanceOf(USER_1);
        MockV3AggregatorAltered(priceFeed).updateAnswer(int256(NEW_PRICE));

        vm.prank(USER_1);
        stabilityEngine.redeemCollateral(collateralValue);

        assertEq(stabilityEngine.getDollarsAmount(USER_1), 0);
        assertEq(
            collateralValue,
            (collateralToken.balanceOf(USER_1) - startingTokens) * stabilityEngine.getFullTokenValue() / PRECISION
        );
        assertEq(stabilityEngine.getFullTokenValue(), NEW_PRICE);
    }
}
