// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FailOnRevertOneToOneHandler} from "test/fuzz/failOnRevert/FailOnRevertOneToOneHandler.t.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {CollateralToken} from "src/CollateralToken.sol";

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title FailOnRevertOneToOneInvariant
 * @dev This contract leverages the Forge invariant testing framework to verify that the StabilityEngine consistently maintains
 *      a 1:1 collateral-to-debt ratio with the associated CollateralToken. It ensures that any changes to the system’s state,
 *      including minting and collateral depositing, do not violate this fundamental invariant.
 *
 * @notice The contract uses fuzz testing to simulate a wide variety of scenarios, ensuring the system behaves as expected under
 *         diverse conditions. It integrates with a specialized handler, `FailOnRevertOneToOneHandler`, which facilitates the
 *         execution of operations such as minting, collateral depositing, and price feed updates, while ensuring the integrity
 *         of the collateral-to-debt ratio.
 *
 * @dev The contract is designed to be used in the context of Forge’s invariant testing, where the `invariant__alwaysOneToOneRatio`
 *      function is called repeatedly to detect any deviations from the desired 1:1 collateral ratio.
 */
contract FailOnRevertOneToOneInvariant is StdInvariant, Test {
    ///////////////////////////////
    ////// STATE VARIABLES ////////
    ///////////////////////////////

    FailOnRevertOneToOneHandler handler; // Handler for executing operations and monitoring the collateral ratio.
    StabilityEngine stabilityEngine; // Instance of the StabilityEngine contract to be tested.
    CollateralToken collateralToken; // Instance of the CollateralToken associated with the StabilityEngine.

    ///////////////////////////////
    //////////// SETUP ////////////
    ///////////////////////////////

    /**
     * @notice Deploys the required contracts and sets up the testing environment.
     *         Initializes the handler for interacting with the StabilityEngine and CollateralToken.
     */
    function setUp() external {
        // Deploy StabilityEngine and its associated contracts.
        Deploy deploy = new Deploy();
        stabilityEngine = deploy.run();
        collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());

        // Initialize the handler to facilitate testing operations.
        handler = new FailOnRevertOneToOneHandler(stabilityEngine, collateralToken);

        // Set the target contract for invariant testing to ensure proper test execution.
        targetContract(address(handler));
    }

    ///////////////////////////////
    ////// INVARIANT FUNCTION /////
    ///////////////////////////////

    /**
     * @notice Invariant function that is invoked during the fuzz testing process to assert that the system maintains a 1:1
     *         collateral-to-debt ratio at all times.
     *
     * @dev This function is intended to be executed continuously by the testing framework. It relies on the handler to execute
     *      minting, collateral depositing, and price feed updates while ensuring that the system adheres to the 1:1 collateral
     *      ratio invariant. If any deviations from this ratio occur, the test will fail.
     */
    function invariant__alwaysOneToOneRatio() public view {
        // Testing is handled within the FailOnRevertOneToOneHandler contract.
    }
}
