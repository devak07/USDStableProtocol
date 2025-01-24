// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {CollateralToken} from "src/CollateralToken.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";

/**
 * @title FailOnRevertOneToOneHandler
 * @dev This contract is used for testing the minting, depositing, and redeeming of collateral in relation to a StabilityEngine.
 * It checks if the collateral value maintains a 1:1 ratio with the token value and reverts if the ratio is violated.
 */
contract FailOnRevertOneToOneHandler is Test {
    // Custom error for revert
    error RevertError();

    // Array of prices for the token
    uint256[] public prices;
    // Array of users who interact with the contract
    address[] public users;
    // Array of users who have been checked
    address[] usersChecked;

    // Mapping to track minted collateral by price and user
    mapping(uint256 priceOfToken => mapping(address user => uint256 amountMinted)) public mintedCollateral;

    // Constants defining the maximum allowed collateral and uint8 value
    uint256 constant MAX_COLLATERAL = type(uint16).max;
    uint256 constant MAX_UINT8 = type(uint8).max;

    // References to the StabilityEngine and CollateralToken contracts
    StabilityEngine stabilityEngine;
    CollateralToken collateralToken;

    // Counters for tracking function calls
    uint256 public mintAndDepositCollateralCounter;
    uint256 public updatePriceFeedCounter;
    uint256 public checkOneToOneRatioCounter;

    /**
     * @dev Constructor for the contract, initializing the StabilityEngine and CollateralToken contracts.
     * @param _stabilityEngine Address of the StabilityEngine contract
     * @param _collateralToken Address of the CollateralToken contract
     */
    constructor(StabilityEngine _stabilityEngine, CollateralToken _collateralToken) {
        stabilityEngine = _stabilityEngine;
        collateralToken = _collateralToken;
    }

    /**
     * @dev Mints and deposits collateral into the StabilityEngine contract.
     * The amount of collateral minted is bounded between 1 and MAX_COLLATERAL.
     * @param _amountOfCollateral The amount of collateral to mint and deposit
     */
    function mintAndDepositCollateral(uint256 _amountOfCollateral) public {
        uint256 amountOfCollateralToMint = bound(_amountOfCollateral, 1, MAX_COLLATERAL);

        // Mint collateral to the sender
        vm.prank(address(stabilityEngine));
        collateralToken.mint(msg.sender, amountOfCollateralToMint);

        // Deposit collateral into the StabilityEngine
        vm.startPrank(msg.sender);
        IERC20(address(collateralToken)).approve(address(stabilityEngine), amountOfCollateralToMint);
        stabilityEngine.depositCollateral(amountOfCollateralToMint);
        vm.stopPrank();

        // Track the price and minted collateral
        prices.push(stabilityEngine.getTokenValue());
        mintedCollateral[stabilityEngine.getTokenValue()][msg.sender] += amountOfCollateralToMint;
        users.push(msg.sender);

        mintAndDepositCollateralCounter++;
    }

    /**
     * @dev Updates the price feed of the collateral token.
     * The price is set to a value bounded between 10e8 and MAX_UINT8 * 1e8.
     * @param _value The value to set for the price feed
     */
    function updatePriceFeed(uint256 _value) public {
        uint256 valueToSet = bound(_value, 10e8, MAX_UINT8 * 1e8);
        MockV3AggregatorOwnable aggregator = MockV3AggregatorOwnable(address(stabilityEngine.getPriceFeedAddress()));

        // Transfer ownership of the aggregator to StabilityEngine if needed
        if (aggregator.owner() != address(stabilityEngine)) {
            vm.prank(aggregator.owner());
            aggregator.transferOwnership(address(stabilityEngine));
        }

        // Update the price feed value
        vm.prank(address(stabilityEngine));
        aggregator.updateAnswer(int256(valueToSet));

        updatePriceFeedCounter++;
    }

    /**
     * @dev Checks if the 1:1 collateral-to-token ratio is maintained. If the value deviates,
     * it redeems the collateral and checks the difference. If the difference exceeds the allowed threshold, it reverts.
     * @param _valueToUpdate The new value for updating the price feed
     */
    function checkOneToOneRatio(uint256 _valueToUpdate) public {
        // Ensure the user has not already been checked
        for (uint256 i = 0; i < usersChecked.length; i++) {
            if (usersChecked[i] == msg.sender) {
                return;
            }
        }

        // Loop through all prices and check the collateral-to-token ratio
        for (uint256 i = 0; i < prices.length; i++) {
            uint256 price = prices[i];
            address user = users[i];
            uint256 collateralAmountBefore = mintedCollateral[price][user];
            uint256 collateralValueBefore = price * collateralAmountBefore;

            // Log the initial values
            console.log("Collateral amount before: ", collateralAmountBefore);
            console.log("Collateral value before: ", collateralValueBefore);
            console.log("Price of one token before: ", price);

            uint256 startingBalanceInWallet = collateralToken.balanceOf(user);

            // Update the price feed
            updatePriceFeed(_valueToUpdate);

            // Log the updated values
            console.log("Dollar in array: ", stabilityEngine.getDollarsAmount(user));
            console.log("Token Value After: ", stabilityEngine.getTokenValue());

            // Check if the collateral value is below the token value, if so, redeem collateral
            if (
                stabilityEngine.getDollarsAmount(user) <= stabilityEngine.getTokenValue()
                    || collateralValueBefore <= stabilityEngine.getTokenValue()
            ) {
                return;
            }

            vm.prank(user);
            stabilityEngine.redeemCollateral(collateralValueBefore);

            uint256 collateralAmountAfter = collateralToken.balanceOf(user) - startingBalanceInWallet;
            uint256 collateralValueAfter = (collateralAmountAfter * stabilityEngine.getFullTokenValue()) / 1e8;

            // Log the after-redeem values
            console.log("Collateral amount after: ", collateralAmountAfter);
            console.log("Collateral value after: ", collateralValueAfter);

            // Check if the difference in collateral value exceeds the threshold and revert if necessary
            if (collateralValueBefore - collateralValueAfter > (stabilityEngine.getTokenValue() + 1)) {
                console.log("Difference: ", collateralValueBefore - collateralValueAfter);
                revert RevertError();
            }

            // Mark the user as checked and reset collateral values
            usersChecked.push(msg.sender);
            for (uint256 j = 0; j < prices.length; j++) {
                mintedCollateral[prices[j]][users[j]] = 0;
            }
            delete prices;
            delete users;

            checkOneToOneRatioCounter++;
        }
    }
}
