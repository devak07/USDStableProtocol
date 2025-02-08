// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {StabilityEngine} from "src/StabilityEngine.sol";
import {MockV3AggregatorAltered} from "test/mocks/MockV3AggregatorAltered.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Script, console} from "forge-std/Script.sol";
import {CollateralToken} from "src/CollateralToken.sol";

/**
 * @title GetTenTokensAndDeposit
 * @author Andrzej Knapik (GitHub: akdev07)
 * @dev This contract is designed to interact with the most recently deployed StabilityEngine contract
 * and perform specific actions for testing purposes. It assumes that the StabilityEngine contract
 * has a method `getTenTokens()` that retrieves ten tokens for the user.
 *
 * This contract is primarily used in test environments to simulate the process of obtaining collateral
 * tokens and depositing them into the StabilityEngine contract. Please note that the functionality of this
 * contract is dependent on the presence of the `getTenTokens()` method in the StabilityEngine contract.
 * If the `getTenTokens()` function is removed from the StabilityEngine contract, this contract will no longer work.
 *
 * The contract performs the following actions:
 * 1. Retrieves 10 tokens using `getTenTokens()` from the StabilityEngine contract.
 * 2. Approves the StabilityEngine contract to spend the retrieved tokens.
 * 3. Deposits the approved tokens into the StabilityEngine contract as collateral.
 *
 * @notice This contract is intended for testing purposes only and should not be used in production.
 * It interacts with the most recent deployment of the StabilityEngine contract, retrieved via the
 * DevOpsTools library.
 */
contract GetTenTokensAndDeposit is Script {
    StabilityEngine stabilityEngine =
        StabilityEngine(DevOpsTools.get_most_recent_deployment("StabilityEngine", block.chainid));
    CollateralToken collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());

    /**
     * @dev Executes the process of getting 10 tokens, approving the StabilityEngine contract to spend them,
     * and depositing them as collateral.
     */
    function run() external {
        vm.startBroadcast();

        // Retrieves 10 tokens from the StabilityEngine contract (this function must exist in StabilityEngine).
        stabilityEngine.getTenTokens();

        // Approves the StabilityEngine contract to spend the 10 tokens.
        collateralToken.approve(address(stabilityEngine), 10);

        // Deposits the approved tokens into the StabilityEngine contract.
        stabilityEngine.depositCollateral(10);

        vm.stopBroadcast();
    }
}
