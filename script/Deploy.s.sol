// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {Config, CONFIGURATION_STRUCT, NETWORK_IDS} from "script/Config.s.sol";
import {TestnetPriceRandomUpdate} from "src/TestnetPriceRandomUpdate.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";

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
     * @return vrfCoordinator The address of the deployed VRF Coordinator (if applicable).
     * @return testnetPriceRandomUpdate The address of the TestnetPriceRandomUpdate contract (if applicable).
     */
    function run() external returns (StabilityEngine, address, TestnetPriceRandomUpdate) {
        Config config = new Config();
        CONFIGURATION_STRUCT.Configuration memory configuration = config.run();

        if (block.chainid == ANVIL_CHAINID) {
            return runOnAnvilMode(configuration);
        }

        vm.startBroadcast();

        // Deploy StabilityEngine using the appropriate price feed.
        StabilityEngine stabilityEngine = new StabilityEngine(configuration.priceFeed);

        vm.stopBroadcast();

        // Placeholder values for testnet-specific deployments.
        address vrfCoordinator;
        TestnetPriceRandomUpdate testnetPriceRandomUpdate;

        return (stabilityEngine, vrfCoordinator, testnetPriceRandomUpdate);
    }

    /**
     * @notice Deploys StabilityEngine and associated contracts in a local Anvil testing environment.
     * @dev Deploys a mock Chainlink price feed and configures a testnet-compatible price update system.
     * @param _configuration The network-specific configuration data.
     * @return stabilityEngine The deployed StabilityEngine instance.
     * @return vrfCoordinator The deployed VRF Coordinator mock contract address.
     * @return testnetPriceRandomUpdate The deployed TestnetPriceRandomUpdate instance.
     */
    function runOnAnvilMode(CONFIGURATION_STRUCT.Configuration memory _configuration)
        internal
        returns (StabilityEngine, address, TestnetPriceRandomUpdate)
    {
        vm.startBroadcast();

        // Deploy a mock Chainlink price feed for local testing.
        MockV3AggregatorOwnable mockV3Aggregator = new MockV3AggregatorOwnable(DECIMALS, STARTING_PRICE);
        vm.stopBroadcast();
        _configuration.priceFeed = address(mockV3Aggregator);

        vm.startBroadcast();

        // Deploy StabilityEngine using the mock price feed.
        StabilityEngine stabilityEngine = new StabilityEngine(_configuration.priceFeed);

        vm.stopBroadcast();

        address vrfCoordinator = _configuration.vrfCoordinator;
        uint256 subscriptionId = _configuration.subscriptionId;
        TestnetPriceRandomUpdate testnetPriceRandomUpdate;

        vm.startBroadcast();

        // Deploy TestnetPriceRandomUpdate to simulate price updates.
        testnetPriceRandomUpdate = new TestnetPriceRandomUpdate(
            address(vrfCoordinator),
            subscriptionId,
            1 days,
            _configuration.priceFeed,
            bytes32(0),
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT
        );

        // Register the new price update contract as a consumer of the VRF service.
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, address(testnetPriceRandomUpdate));

        // Transfer ownership of the mock price feed to the price update contract.
        mockV3Aggregator.transferOwnership(address(testnetPriceRandomUpdate));

        vm.stopBroadcast();

        return (stabilityEngine, vrfCoordinator, testnetPriceRandomUpdate);
    }
}
