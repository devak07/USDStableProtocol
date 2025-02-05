// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {CollateralToken} from "src/CollateralToken.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";

/**
 * @title FailOnRevertHandler
 * @author Andrzej Knapik (GitHub: devak07)
 * @notice This contract is a test handler designed to interact with the StabilityEngine and CollateralToken contracts.
 *         It provides functions to mint, deposit, and redeem collateral, as well as update the price feed. It ensures
 *         that the operations conform to expected behaviors and tracks execution counts.
 * @dev This contract is intended for use in Foundry-based tests to validate StabilityEngine behavior.
 */
contract FailOnRevertHandler is Test {
    /////////////////////////////
    ////////// CONSTANTS ////////
    /////////////////////////////

    uint256 constant MAX_COLLATERAL = type(uint16).max; // Maximum allowable collateral value for testing
    uint256 constant MAX_UINT16 = type(uint16).max; // Maximum value of a uint16 variable (used for price updates)
    uint256 constant PRECISION = 1e8; // Precision factor for token values
    uint256 constant MIN_COLLATERAL = 1e9;

    /////////////////////////////
    ////// STATE VARIABLES //////
    /////////////////////////////

    StabilityEngine stabilityEngine; // Instance of the StabilityEngine contract
    CollateralToken collateralToken; // Instance of the CollateralToken contract

    // Counters to track function calls
    uint256 public redeemCollateralCounter; // Tracks number of times collateral is redeemed
    uint256 public mintAndDepositCollateralCounter; // Tracks number of times collateral is minted and deposited
    uint256 public updatePriceFeedCounter; // Tracks number of times the price feed is updated

    /////////////////////////////
    //////// CONSTRUCTOR ////////
    /////////////////////////////

    /**
     * @dev Initializes the handler with StabilityEngine and CollateralToken instances.
     * @param _stabilityEngine The address of the deployed StabilityEngine contract.
     * @param _collateralToken The address of the deployed CollateralToken contract.
     */
    constructor(StabilityEngine _stabilityEngine, CollateralToken _collateralToken) {
        stabilityEngine = _stabilityEngine;
        collateralToken = _collateralToken;
    }

    /////////////////////////////
    //////// FUNCTIONS //////////
    /////////////////////////////

    /**
     * @notice Mints and deposits collateral into the StabilityEngine.
     * @dev Ensures the minted amount is within the valid range and deposits it into StabilityEngine.
     * @param _amountOfCollateral The amount of collateral to mint and deposit.
     */
    function mintAndDepositCollateral(uint256 _amountOfCollateral) public {
        // Bound the amount of collateral within a reasonable range
        uint256 amountOfCollateralToMint = bound(_amountOfCollateral, MIN_COLLATERAL, MAX_COLLATERAL * 1e5);

        // Mint the collateral to the sender's address
        vm.prank(address(stabilityEngine));
        collateralToken.mint(msg.sender, amountOfCollateralToMint);

        // Approve and deposit the collateral into StabilityEngine
        vm.startPrank(msg.sender);
        IERC20(address(collateralToken)).approve(address(stabilityEngine), amountOfCollateralToMint);
        stabilityEngine.depositCollateral(amountOfCollateralToMint);
        vm.stopPrank();

        // Increment the counter for tracking
        mintAndDepositCollateralCounter++;
    }

    /**
     * @notice Redeems collateral from StabilityEngine.
     * @dev Ensures that the sender has enough collateral before redemption. If not, collateral is minted first.
     * @param _amountOfCollateral The amount of collateral to redeem.
     */
    function redeemCollateral(uint256 _amountOfCollateral) public {
        // Bound the amount of collateral within a valid range
        uint256 collateralToRedeem = bound(_amountOfCollateral, MIN_COLLATERAL, MAX_COLLATERAL * 1e5);

        // If the sender does not have enough collateral, mint and deposit collateral first
        mintAndDepositCollateral(collateralToRedeem);

        // Ensure the collateral value is within valid limits
        if (
            collateralToRedeem * PRECISION <= stabilityEngine.getFullTokenValue()
                || msg.sender == address(stabilityEngine)
        ) {
            return;
        }

        // Redeem collateral based on StabilityEngine's valuation
        address user = msg.sender;
        vm.startPrank(user);
        stabilityEngine.redeemCollateral((collateralToRedeem * stabilityEngine.getFullTokenValue()) / PRECISION);
        vm.stopPrank();

        // Increment the counter for tracking
        redeemCollateralCounter++;
    }

    /**
     * @notice Updates the price feed for StabilityEngine.
     * @dev Ensures the price is set within a valid range and transfers ownership if required.
     * @param _value The new value to set for the price feed.
     */
    function updatePriceFeed(uint256 _value) public {
        // Bound the price value to a valid range
        uint256 valueToSet = bound(_value, 1, MAX_UINT16); // Ensures the price value is reasonable

        // Get the price feed aggregator contract
        MockV3AggregatorOwnable aggregator = MockV3AggregatorOwnable(address(stabilityEngine.getPriceFeedAddress()));

        // Ensure StabilityEngine owns the price feed, transfer ownership if necessary
        if (aggregator.owner() != address(stabilityEngine)) {
            vm.prank(aggregator.owner());
            aggregator.transferOwnership(address(stabilityEngine));
        }

        // Update the price feed
        vm.prank(address(stabilityEngine));
        aggregator.updateAnswer(int256(valueToSet));

        // Increment the counter for tracking
        updatePriceFeedCounter++;
    }
}
