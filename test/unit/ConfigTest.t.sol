// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.26;

// // Importing necessary dependencies for testing and configuration
// import {Test} from "forge-std/Test.sol";
// import {Config, NETWORK_IDS, CONFIGURATION_STRUCT} from "script/Config.s.sol";
// import {MockV3AggregatorAltered} from "test/mocks/MockV3AggregatorAltered.sol";

// /**
//  * @title ConfigTest
//  * @author Andrzej Knapik (GitHub: akdev07)
//  * @dev This contract is a test suite for verifying blockchain network configurations.
//  */
// contract ConfigTest is Test {
//     ////////////////////////////
//     //////// VARIABLES /////////
//     ////////////////////////////

//     // Address of the Ethereum mainnet price feed (set to a placeholder value)
//     address private constant ETH_MAINNET_PRICE_FEED = address(0);

//     // The expected starting price from the configuration in the test (formatted in 8 decimals)
//     int256 private constant STARTING_PRICE_FROM_CONFIG = 10e8;

//     // Instance of the Config contract, which manages network configurations
//     Config config;

//     // Struct instance to store the retrieved configuration
//     CONFIGURATION_STRUCT.Configuration configuration;

//     //Placeholder, not used in this case
//     function setUp() external {}

//     /////////////////////////////
//     ///////// FUNCTIONS /////////
//     /////////////////////////////

//     /**
//      * @dev Modifier to create a forked blockchain state and deploy a new configuration.
//      * @param _aliasForkUrl The alias URL for the forked blockchain (e.g., "rpc-ethmainnet" or "rpc-amoy").
//      */
//     modifier forkAndCreateNewConfig(string memory _aliasForkUrl) {
//         vm.createSelectFork(_aliasForkUrl); // Fork the specified blockchain network
//         config = new Config(); // Deploy a new instance of the Config contract
//         configuration = config.run(); // Retrieve the configuration settings
//         _; // Continue execution of the function using this modifier
//     }

//     /**
//      * @dev Test case to verify the Ethereum Mainnet configuration.
//      * Ensures that the price feed matches the expected mainnet address.
//      */
//     function testEthMainnet() external forkAndCreateNewConfig("rpc-ethmainnet") {
//         assertEq(configuration.priceFeed, ETH_MAINNET_PRICE_FEED);
//     }

//     /**
//      * @dev Test case to verify the configuration for the Amoy Testnet.
//      * Checks whether the price feed returns the expected starting price.
//      */
//     function testAmoyTestnetConfiguration() external forkAndCreateNewConfig("rpc-amoy") {
//         // Retrieve the latest price data from the configured price feed
//         (, int256 answer,,,) = MockV3AggregatorAltered(configuration.priceFeed).latestRoundData();

//         // Ensure the reported price matches the expected test value
//         assertEq(answer, STARTING_PRICE_FROM_CONFIG);
//     }
// }
