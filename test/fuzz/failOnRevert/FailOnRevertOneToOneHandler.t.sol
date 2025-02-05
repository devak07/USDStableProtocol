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
 * @title FailOnRevertOneToOneHandler
 * @author Andrzej Knapik (devak07)
 * @notice This contract is used for invariant testing related to collateral minting, depositing, and redeeming.
 *         It ensures that the StabilityEngine maintains a 1:1 collateral-to-token ratio and reverts if this is violated.
 * @dev Uses Foundry's `Test` framework for fuzz testing.
 */
contract FailOnRevertOneToOneHandler is Test {
    /////////////////////////////
    ////// STATE VARIABLES //////
    /////////////////////////////

    /// @notice Custom error thrown if the 1:1 collateral-to-token ratio is violated.
    error RevertError();

    /// @notice Array to store past token prices for tracking collateral value changes.
    uint256[] public prices;

    /// @notice Array of users who interact with the contract.
    address[] public users;

    /// @notice Array of users who have been checked for 1:1 collateral-to-token ratio compliance.
    address[] usersChecked;

    /// @notice Mapping to track minted collateral per price and user.
    mapping(uint256 priceOfToken => mapping(address user => uint256 amountMinted)) public mintedCollateral;

    /// @notice Maximum amount of collateral that can be minted.
    uint256 constant MAX_COLLATERAL = type(uint16).max;

    /// @notice Maximum value for an 8-bit integer.
    uint256 constant MAX_UINT8 = type(uint8).max;

    /// @notice References to the StabilityEngine and CollateralToken contracts.
    StabilityEngine stabilityEngine;
    CollateralToken collateralToken;

    /// @notice Counters to track function calls for analysis.
    uint256 public mintAndDepositCollateralCounter;
    uint256 public updatePriceFeedCounter;
    uint256 public checkOneToOneRatioCounter;

    /////////////////////////////
    //////// FUNCTIONS //////////
    /////////////////////////////

    /**
     * @dev Contract constructor, initializing the StabilityEngine and CollateralToken.
     * @param _stabilityEngine Address of the StabilityEngine contract.
     * @param _collateralToken Address of the CollateralToken contract.
     */
    constructor(StabilityEngine _stabilityEngine, CollateralToken _collateralToken) {
        stabilityEngine = _stabilityEngine;
        collateralToken = _collateralToken;
    }

    /**
     * @dev Mints and deposits collateral into the StabilityEngine contract.
     *      The amount of collateral is bounded between 1 and MAX_COLLATERAL.
     * @param _amountOfCollateral The amount of collateral to mint and deposit.
     */
    function mintAndDepositCollateral(uint256 _amountOfCollateral) public {
        uint256 amountOfCollateralToMint = bound(_amountOfCollateral, 1, MAX_COLLATERAL);

        // Mint collateral for the sender
        vm.prank(address(stabilityEngine));
        collateralToken.mint(msg.sender, amountOfCollateralToMint);

        // Deposit collateral into the StabilityEngine
        vm.startPrank(msg.sender);
        IERC20(address(collateralToken)).approve(address(stabilityEngine), amountOfCollateralToMint);
        stabilityEngine.depositCollateral(amountOfCollateralToMint);
        vm.stopPrank();

        // Store price and track minted collateral
        uint256 currentPrice = stabilityEngine.getTokenValue();
        prices.push(currentPrice);
        mintedCollateral[currentPrice][msg.sender] += amountOfCollateralToMint;
        users.push(msg.sender);

        mintAndDepositCollateralCounter++;
    }

    /**
     * @dev Updates the price feed of the collateral token.
     *      The price is bounded between 0.00000001 and MAX_UINT8.
     * @param _value The new value to set in the price feed.
     */
    function updatePriceFeed(uint256 _value) public {
        uint256 valueToSet = bound(_value, 1, MAX_UINT8 * 1e8);
        MockV3AggregatorOwnable aggregator = MockV3AggregatorOwnable(address(stabilityEngine.getPriceFeedAddress()));

        // Transfer ownership of the aggregator to StabilityEngine if needed
        if (aggregator.owner() != address(stabilityEngine)) {
            vm.prank(aggregator.owner());
            aggregator.transferOwnership(address(stabilityEngine));
        }

        // Update the price feed
        vm.prank(address(stabilityEngine));
        aggregator.updateAnswer(int256(valueToSet));

        updatePriceFeedCounter++;
    }

    /**
     * @dev Checks if the 1:1 collateral-to-token ratio is maintained. If the value deviates,
     *      it redeems the collateral and verifies the difference. If the deviation exceeds the threshold, it reverts.
     * @param _valueToUpdate The new value for updating the price feed.
     */
    function checkOneToOneRatio(uint256 _valueToUpdate) public {
        // Ensure the user hasn't already been checked
        for (uint256 i = 0; i < usersChecked.length; i++) {
            if (usersChecked[i] == msg.sender) {
                return;
            }
        }

        // Loop through all stored prices and check collateral-to-token ratios
        for (uint256 i = 0; i < prices.length; i++) {
            uint256 price = prices[i];
            address user = users[i];
            uint256 collateralAmountBefore = mintedCollateral[price][user];
            uint256 collateralValueBefore = price * collateralAmountBefore;

            uint256 startingBalanceInWallet = collateralToken.balanceOf(user);

            // Update the price feed before checking the ratio
            updatePriceFeed(_valueToUpdate);

            // If the collateral value is already within limits, skip redemption
            if (
                stabilityEngine.getDollarsAmount(user) <= stabilityEngine.getTokenValue()
                    || collateralValueBefore <= stabilityEngine.getTokenValue()
            ) {
                return;
            }

            // Redeem collateral
            vm.prank(user);
            stabilityEngine.redeemCollateral(collateralValueBefore);

            uint256 collateralAmountAfter = collateralToken.balanceOf(user) - startingBalanceInWallet;
            uint256 collateralValueAfter = (collateralAmountAfter * stabilityEngine.getFullTokenValue()) / 1e8;

            // If the difference in value exceeds the threshold, revert
            if (collateralValueBefore - collateralValueAfter > (stabilityEngine.getTokenValue() + 1)) {
                revert RevertError();
            }

            // Mark user as checked and clear collateral tracking
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
