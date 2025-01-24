// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";

/**
 * @title Config Contract
 * @dev Provides network-specific configurations for the system. It supports local, testnet, and mainnet environments.
 *      The current implementation supports mock price feeds for testing and will be extended with automatic price updates
 *      for the Amoy testnet. Note that the system cannot operate on the Ethereum mainnet or testnet without a Chainlink price node.
 */
contract Config is Script {
    /**
     * @notice Determines the appropriate configuration based on the network ID.
     * @return The address of the network-specific configuration contract or mock price feed.
     */
    function run() external returns (address) {
        if (block.chainid == 1) {
            return getEthMainnetConfiguration();
        } else if (block.chainid == 80002) {
            return getAmoyTestnetConfiguration();
        } else {
            return getAnvilLocalConfiguration();
        }
    }

    /**
     * @notice Provides the Ethereum mainnet configuration.
     * @dev Currently, the mainnet configuration is unavailable. A Chainlink price node is required for the system to operate.
     * @return The address of the mainnet configuration contract, set to `address(0)` as a placeholder.
     */
    function getEthMainnetConfiguration() private pure returns (address) {
        return address(0); // Placeholder, requires Chainlink price node.
    }

    /**
     * @notice Deploys and returns a mock price feed for the Amoy testnet.
     * @dev In the future, this will include functionality for automatic price updates from the mock implementation.
     * @return The address of the deployed `MockV3AggregatorOwnable` for the Amoy testnet.
     */
    function getAmoyTestnetConfiguration() private returns (address) {
        MockV3AggregatorOwnable mockV3Aggregator = new MockV3AggregatorOwnable(8, 10e8);
        // TODO: Implement automatic price update functionality.
        return address(mockV3Aggregator);
    }

    /**
     * @notice Deploys and returns a mock price feed for the local Anvil environment.
     * @return The address of the deployed `MockV3AggregatorOwnable` for local testing.
     */
    function getAnvilLocalConfiguration() private returns (address) {
        MockV3AggregatorOwnable mockV3Aggregator = new MockV3AggregatorOwnable(8, 10e8);
        return address(mockV3Aggregator);
    }
}
