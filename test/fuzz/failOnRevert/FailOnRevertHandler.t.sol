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
 * @dev This contract handles testing logic related to minting, redeeming, and price feed updating for the StabilityEngine and CollateralToken contracts.
 * It tracks the number of times certain functions are called and provides the functionality for testing minting, depositing, and redeeming collateral.
 */
contract FailOnRevertHandler is Test {
    error RevertError();

    // Constants
    uint256 constant MAX_COLLATERAL = type(uint16).max;
    uint256 constant MAX_UINT16 = type(uint16).max;

    // Instances of required contracts for testing
    StabilityEngine stabilityEngine;
    CollateralToken collateralToken;

    // Counters for tracking the number of times certain actions are performed
    uint256 public redeemCollateralCounter;
    uint256 public mintAndDepositCollateralCounter;
    uint256 public updatePriceFeedCounter;

    /**
     * @dev Constructor that sets the StabilityEngine and CollateralToken contract instances.
     * @param _stabilityEngine The address of the deployed StabilityEngine contract.
     * @param _collateralToken The address of the deployed CollateralToken contract.
     */
    constructor(StabilityEngine _stabilityEngine, CollateralToken _collateralToken) {
        stabilityEngine = _stabilityEngine;
        collateralToken = _collateralToken;
    }

    /**
     * @dev Mints and deposits collateral into the StabilityEngine contract.
     * @param _amountOfCollateral The amount of collateral to mint and deposit.
     * @notice This function ensures the amount of collateral to mint is within a defined range.
     */
    function mintAndDepositCollateral(uint256 _amountOfCollateral) public {
        // Bound the amount of collateral to mint to a valid range
        uint256 amountOfCollateralToMint = bound(_amountOfCollateral, 1, MAX_COLLATERAL);

        // Mint the collateral to the sender's address
        vm.prank(address(stabilityEngine));
        collateralToken.mint(msg.sender, amountOfCollateralToMint);

        // Approve and deposit the collateral into the StabilityEngine
        vm.startPrank(msg.sender);
        IERC20(address(collateralToken)).approve(address(stabilityEngine), amountOfCollateralToMint);
        stabilityEngine.depositCollateral(amountOfCollateralToMint);
        vm.stopPrank();

        // Increment the mint and deposit counter
        mintAndDepositCollateralCounter++;
    }

    /**
     * @dev Redeems collateral from the StabilityEngine contract.
     * @param _amountOfCollateral The amount of collateral to redeem.
     * @notice This function ensures the amount of collateral to redeem is within a valid range and that the sender has enough collateral.
     */
    function redeemCollateral(uint256 _amountOfCollateral) public {
        // Bound the amount of collateral to redeem to a valid range
        uint256 collateralToRedeem = bound(_amountOfCollateral, 1, MAX_COLLATERAL);

        // If the sender does not have enough collateral, mint and deposit collateral
        if (IERC20(address(collateralToken)).balanceOf(msg.sender) < collateralToRedeem) {
            mintAndDepositCollateral(collateralToRedeem);
        }

        // If the collateral value is within valid limits, do not proceed with redemption
        if (collateralToRedeem <= stabilityEngine.getTokenValue() || msg.sender == address(stabilityEngine)) {
            return;
        }

        // Redeem the collateral
        vm.prank(msg.sender);
        stabilityEngine.redeemCollateral(collateralToRedeem);

        // Increment the redeem collateral counter
        redeemCollateralCounter++;
    }

    /**
     * @dev Updates the price feed in the StabilityEngine contract.
     * @param _value The value to set for the price feed.
     * @notice This function updates the price feed after ensuring that the value is within a valid range.
     */
    function updatePriceFeed(uint256 _value) public {
        // Bound the price value to a valid range
        uint256 valueToSet = bound(_value, 10e8, MAX_UINT16 * 1e8); // 10e8 will be adjusted after refactoring to work with price values greater than 10

        // Get the aggregator and transfer ownership if necessary
        MockV3AggregatorOwnable aggregator = MockV3AggregatorOwnable(address(stabilityEngine.getPriceFeedAddress()));
        if (aggregator.owner() != address(stabilityEngine)) {
            vm.prank(aggregator.owner());
            aggregator.transferOwnership(address(stabilityEngine));
        }

        // Update the price feed
        vm.prank(address(stabilityEngine));
        aggregator.updateAnswer(int256(valueToSet));

        // Increment the update price feed counter
        updatePriceFeedCounter++;
    }
}
