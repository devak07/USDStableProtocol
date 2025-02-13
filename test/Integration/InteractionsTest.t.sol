// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {GetTenTokensAndDeposit} from "script/Interactions.s.sol";
import {Deploy} from "script/Deploy.s.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @title InteractionsTest
 * @author Andrzej Knapik (GitHub: akdev07)
 * @dev A test contract for interacting with the StabilityEngine.
 * It deploys the StabilityEngine, forks the blockchain, and performs an interaction.
 */
contract InteractionsTest is Test {
    ////////////////////////////
    //////// VARIABLES /////////
    ////////////////////////////

    uint256 private constant TEN_TOKENS = 10; // Constant representing ten tokens
    uint256 private constant PRECISION = 1e18; // Precision factor for calculations

    StabilityEngine stabilityEngine; // Instance of the StabilityEngine
    address USER = makeAddr("USER"); // Address of a test user

    ////////////////////////////
    ///////// SETUP ////////////
    ////////////////////////////

    /**
     * @dev Setup function executed before each test.
     * It deploys the StabilityEngine, forks the blockchain state, and runs a deposit interaction.
     */
    function setUp() external {
        Deploy deploy = new Deploy(); // Create a new deployment instance
        stabilityEngine = deploy.run(); // Deploy the StabilityEngine contract

        vm.createSelectFork("anvil-rpc"); // Create and select a fork of the blockchain

        GetTenTokensAndDeposit getTenTokensAndDeposit = new GetTenTokensAndDeposit(); // Create an instance of the deposit interaction
        getTenTokensAndDeposit.run(); // Execute the deposit interaction
    }

    /////////////////////////////
    ///////// FUNCTIONS /////////
    /////////////////////////////

    /**
     * @dev Test function to verify that ten tokens are deposited correctly.
     * It checks if the expected dollar amount matches the retrieved value from the StabilityEngine.
     */
    function testGetTenTokensAndDeposit() external view {
        assertEq(
            (TEN_TOKENS * stabilityEngine.getFullTokenValue() / PRECISION), // Expected dollar amount
            stabilityEngine.getDollarsAmount(msg.sender) // Actual retrieved dollar amount
        );
    }
}
