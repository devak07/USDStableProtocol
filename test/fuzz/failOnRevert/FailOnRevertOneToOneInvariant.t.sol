// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FailOnRevertOneToOneHandler} from "test/fuzz/failOnRevert/FailOnRevertOneToOneHandler.t.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {CollateralToken} from "src/CollateralToken.sol";

/**
 * @title FailOnRevertOneToOneInvariant
 * @dev This contract tests the one-to-one collateral ratio in the StabilityEngine system using Forge's invariant testing framework.
 *
 * @notice The contract ensures that the `StabilityEngine` always maintains a 1:1 collateral ratio with the `CollateralToken`.
 * It utilizes fuzz testing to generate a wide range of scenarios to validate the system's behavior.
 *
 * @notice The contract requires a `FailOnRevertOneToOneHandler` to execute operations like minting and depositing collateral
 * and updating price feeds. It captures any deviations from the expected 1:1 ratio invariant during the tests.
 */
contract FailOnRevertOneToOneInvariant is StdInvariant, Test {
    FailOnRevertOneToOneHandler handler; // Handler to execute operations for invariant testing.
    StabilityEngine stabilityEngine; // Instance of the StabilityEngine contract being tested.
    CollateralToken collateralToken; // Instance of the CollateralToken associated with the StabilityEngine.

    /**
     * @notice Sets up the test environment by deploying the StabilityEngine and CollateralToken contracts.
     * Also initializes the handler to perform operations on the system.
     */
    function setUp() external {
        // Deploy StabilityEngine and its dependencies.
        Deploy deploy = new Deploy();
        stabilityEngine = deploy.run();
        collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());

        // Initialize the handler with the deployed contracts.
        handler = new FailOnRevertOneToOneHandler(stabilityEngine, collateralToken);

        // Specify the target contract for invariant testing.
        targetContract(address(handler));
    }

    /**
     * @notice Invariant function to validate that the system maintains a 1:1 collateral-to-debt ratio.
     * @dev This function is executed repeatedly during invariant testing.
     * It verifies that the number of successful mint-and-deposit operations aligns with updates in the price feed
     * while maintaining the one-to-one collateral ratio.
     */
    function invariant__alwaysOneToOneRatio() public view {
        console.log(
            handler.checkOneToOneRatioCounter(), // Count of one-to-one ratio checks performed.
            handler.mintAndDepositCollateralCounter(), // Count of mint-and-deposit operations executed.
            handler.updatePriceFeedCounter() // Count of price feed updates triggered.
        );
    }
}
