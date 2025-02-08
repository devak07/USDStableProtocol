// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {Config, CONFIGURATION_STRUCT, NETWORK_IDS} from "script/Config.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockV3AggregatorAltered} from "test/mocks/MockV3AggregatorAltered.sol";

/**
 * @title Deployment Script
 * @author Andrzej Knapik (GitHub: devak07)
 * @notice This contract handles the deployment of the StabilityEngine contract, along with required mock dependencies.
 * It adapts deployment logic based on the detected blockchain environment (local, testnet, or mainnet).
 * Uses Foundry's scripting tools to facilitate deployment.
 */
contract Deploy is Script, CONFIGURATION_STRUCT, NETWORK_IDS {
    int256 constant STARTING_PRICE = 10e8;
    uint8 constant DECIMALS = 8;
    uint32 constant CALLBACK_GAS_LIMIT = 1e9;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    /**
     * @notice Deploys StabilityEngine and associated contracts based on the detected network.
     * @return stabilityEngine The deployed StabilityEngine contract instance.
     */
    function run() external returns (StabilityEngine) {
        Config config = new Config();
        CONFIGURATION_STRUCT.Configuration memory configuration = config.run();

        vm.startBroadcast();

        // Deploy StabilityEngine using the appropriate price feed.
        StabilityEngine stabilityEngine = new StabilityEngine(configuration.priceFeed);

        vm.stopBroadcast();

        return (stabilityEngine);
    }
}
