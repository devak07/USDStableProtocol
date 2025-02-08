// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FailOnRevertHandler} from "test/fuzz/failOnRevert/FailOnRevertHandler.t.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {CollateralToken} from "src/CollateralToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title FailOnRevertInvariants
 * @author Andrzej Knapik (GitHub: devak07)
 * @notice This contract is designed to perform invariant tests on the StabilityEngine contract to ensure that:
 *         - The StabilityEngine never holds collateral tokens.
 *         - Getter functions in the StabilityEngine contract do not revert.
 * @dev It uses Foundry's `StdInvariant` for property-based testing.
 */
contract FailOnRevertInvariants is StdInvariant, Test {
    /////////////////////////////
    ////// STATE VARIABLES //////
    /////////////////////////////

    FailOnRevertHandler handler; // Instance of the handler contract for executing actions
    StabilityEngine stabilityEngine; // Instance of the StabilityEngine contract
    CollateralToken collateralToken; // Instance of the CollateralToken contract

    /////////////////////////////
    //////// FUNCTIONS //////////
    /////////////////////////////

    /**
     * @dev Sets up the testing environment by deploying contracts and setting up the invariant test target.
     * @notice Deploys the StabilityEngine and CollateralToken contracts, then initializes the FailOnRevertHandler.
     */
    function setUp() external {
        // Deploy the contracts using the Deploy script
        Deploy deploy = new Deploy();
        stabilityEngine = deploy.run();

        // Get the deployed CollateralToken instance from StabilityEngine
        collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());

        // Create an instance of the FailOnRevertHandler
        handler = new FailOnRevertHandler(stabilityEngine, collateralToken);

        // Set the handler contract as the target for invariant testing
        targetContract(address(handler));
    }

    /**
     * @dev Invariant test to ensure the StabilityEngine contract never holds collateral tokens.
     * @notice This guarantees that all collateral tokens remain with users and are not stored in the StabilityEngine.
     */
    function invariant__stabilityEngineCantHaveCollateralTokens() public view {
        // Assert that the StabilityEngine's balance of collateral tokens is always zero
        assertEq(IERC20(address(collateralToken)).balanceOf(address(stabilityEngine)), 0);
    }

    /**
     * @dev Invariant test to ensure that the StabilityEngine's getter functions do not revert.
     * @notice This verifies that getter functions always return valid values and do not throw errors.
     */
    function invariant__gettersCantRevert() public view {
        // Ensure that calling getter functions does not revert
        stabilityEngine.getCollateralTokenAddress();
        stabilityEngine.getPriceFeedAddress();
    }
}
