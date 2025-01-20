// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";

/**
 * @title Deploy Contract
 * @author Andrzej Knapik (devak07)
 * @dev This contract is responsible for deploying a new instance of the StabilityEngine contract.
 * It leverages Forge's Script feature to handle deployment scripts.
 * The deployment occurs during the setup phase and is broadcasted to the Ethereum network.
 */
contract Deploy is Script {
    /**
     * @dev Deploys a new instance of the StabilityEngine contract.
     * The deployment is handled in the setup function and is broadcasted to the Ethereum network.
     *
     * @return stabilityEngine The deployed instance of the StabilityEngine contract.
     */
    function setUp() external returns (StabilityEngine) {
        // Start broadcasting transactions to the network
        vm.startBroadcast();

        // Create and deploy a new instance of the StabilityEngine contract
        StabilityEngine stabilityEngine = new StabilityEngine();

        // Stop broadcasting transactions after the deployment
        vm.stopBroadcast();

        // Return the deployed instance of StabilityEngine
        return stabilityEngine;
    }
}
