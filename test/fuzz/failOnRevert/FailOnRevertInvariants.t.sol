// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FailOnRevertHandler} from "test/fuzz/failOnRevert/FailOnRevertHandler.t.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {CollateralToken} from "src/CollateralToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title FailOnRevertInvariants
 * @dev This contract is used for running invariant tests on the StabilityEngine and FailOnRevertHandler.
 * It checks that the StabilityEngine doesn't hold collateral tokens and that the getters in StabilityEngine don't revert.
 */
contract FailOnRevertInvariants is StdInvariant, Test {
    // Instances of the required contracts for testing
    FailOnRevertHandler handler;
    StabilityEngine stabilityEngine;
    CollateralToken collateralToken;

    /**
     * @dev Set up the environment for the tests. Deploys the contracts and sets up the target contract.
     */
    function setUp() external {
        // Deploy the contracts
        Deploy deploy = new Deploy();
        stabilityEngine = deploy.run();
        collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());
        handler = new FailOnRevertHandler(stabilityEngine, collateralToken);

        // Set the target contract for invariants
        targetContract(address(handler));
    }

    /**
     * @dev Invariant test to ensure that the StabilityEngine never holds any collateral tokens.
     * @notice This ensures that collateral tokens are always in the hands of users, not the StabilityEngine.
     */
    function invariant__stabilityEngineCantHaveCollateralTokens() public view {
        // Assert that the StabilityEngine has no collateral tokens
        assertEq(IERC20(address(collateralToken)).balanceOf(address(stabilityEngine)), 0);

        // Log the internal counters from the FailOnRevertHandler for monitoring
        console.log(
            handler.redeemCollateralCounter(),
            handler.mintAndDepositCollateralCounter(),
            handler.updatePriceFeedCounter()
        );
    }

    /**
     * @dev Invariant test to ensure that the getter functions in the StabilityEngine contract do not revert.
     * @notice This checks that the StabilityEngine contract's getter functions work correctly and do not revert.
     */
    function invariant__gettersCantRevert() public view {
        // Ensure getter functions don't revert by calling them
        stabilityEngine.getCollateralTokenAddress();
        stabilityEngine.getPriceFeedAddress();

        // Log the internal counters from the FailOnRevertHandler for monitoring
        console.log(
            handler.redeemCollateralCounter(),
            handler.mintAndDepositCollateralCounter(),
            handler.updatePriceFeedCounter()
        );
    }
}
