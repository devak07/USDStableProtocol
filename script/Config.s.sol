// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";
import {TestnetPriceRandomUpdate} from "src/TestnetPriceRandomUpdate.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title Configuration Structure
 * @dev Defines a struct for network-specific configurations, including price feed and VRF coordinator addresses.
 */
contract CONFIGURATION_STRUCT {
    struct Configuration {
        address priceFeed;
        address vrfCoordinator;
        uint256 subscriptionId;
    }
}

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title Network Identifiers
 * @dev Provides constants representing different blockchain network IDs.
 */
contract NETWORK_IDS {
    uint256 constant ANVIL_CHAINID = 31337; // Local development network (Anvil)
    uint256 constant AMOY_CHAINID = 80002; // Amoy Testnet
    uint256 ETH_MAINNET_CHAINID = 1; // Ethereum Mainnet
}

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title Config Contract
 * @dev Manages the deployment and retrieval of network-specific configurations, including price feeds and VRF settings.
 */
contract Config is Script, CONFIGURATION_STRUCT, NETWORK_IDS {
    uint256 constant FUNDING_AMOUNT = 100e18; // Amount used to fund VRF subscription
    int256 constant WEI_PER_UNIT_LINK = 7e15; // Conversion rate for LINK token pricing
    int256 constant STARTING_PRICE = 10e8; // Initial mock price for price feeds
    uint96 constant BASE_FEE = 1e17; // Base fee for VRF requests
    uint96 constant GAS_PRICE = 1e9; // Gas price for VRF requests
    uint8 constant DECIMALS = 8; // Decimal precision for price feeds

    /**
     * @notice Retrieves the appropriate configuration based on the current network ID.
     * @return A Configuration struct containing network-specific contract addresses.
     */
    function run() external returns (Configuration memory) {
        if (block.chainid == ETH_MAINNET_CHAINID) {
            return getEthMainnetConfiguration();
        } else if (block.chainid == AMOY_CHAINID) {
            return getAmoyTestnetConfiguration();
        } else {
            return getAnvilLocalConfiguration();
        }
    }

    /**
     * @notice Provides the Ethereum mainnet configuration.
     * @dev Currently, the mainnet configuration is unavailable due to the absence of a Chainlink price node.
     * @return A Configuration struct with placeholder addresses set to `address(0)`.
     */
    function getEthMainnetConfiguration() private pure returns (Configuration memory) {
        return Configuration(address(0), address(0), 0);
    }

    /**
     * @notice Deploys a mock price feed for the Amoy testnet.
     * @dev This function deploys a `MockV3AggregatorOwnable` contract with a predefined starting price.
     *      Chainlink VRF subscriptions must be manually created when deploying to Amoy.
     * @return A Configuration struct containing the deployed mock price feed address.
     */
    function getAmoyTestnetConfiguration() private returns (Configuration memory) {
        MockV3AggregatorOwnable mockV3Aggregator = new MockV3AggregatorOwnable(DECIMALS, STARTING_PRICE);
        return Configuration(address(mockV3Aggregator), address(0), 0);
    }

    /**
     * @notice Deploys mock contracts for local Anvil testing.
     * @dev This function deploys a mock VRFCoordinator and creates a funded subscription for testing.
     * @return A Configuration struct containing the VRF coordinator address and subscription ID.
     */
    function getAnvilLocalConfiguration() private returns (Configuration memory) {
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE, WEI_PER_UNIT_LINK);
        uint256 subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, FUNDING_AMOUNT);

        vm.stopBroadcast();

        return Configuration(address(0), address(vrfCoordinator), subscriptionId);
    }
}
