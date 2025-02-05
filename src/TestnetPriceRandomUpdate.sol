// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title TestnetPriceRandomUpdate
 * @author Andrzej Knapik (GitHub: devak07)
 * @notice This contract is responsible for updating the price of the collateral token on a testnet.
 *         It uses Chainlink VRF (Verifiable Random Function) to generate pseudo-random price updates
 *         and Chainlink Automation (formerly Keepers) to schedule updates at regular intervals.
 *         The updated prices are then stored and used by the StabilityEngine contract.
 *
 * @dev This contract interacts with:
 *      - Chainlink VRF for random price updates
 *      - Chainlink Automation for scheduling updates
 *      - A mock Chainlink price feed (MockV3AggregatorOwnable) for updating the price
 */
contract TestnetPriceRandomUpdate is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /////////////////////////////
    ////////// ERRORS ///////////
    /////////////////////////////

    /**
     * @dev Error triggered when an update is attempted before the required interval has passed.
     */
    error TestnetPriceRandomUpdate__NotEnoughTimePassed();

    /////////////////////////////
    ////// STATE VARIABLES //////
    /////////////////////////////

    uint256 private constant MAX_PRICE = 1000e8; // Maximum possible price value (scaled to 8 decimals).
    uint32 private constant NUM_WORDS = 1; // Number of random words requested from Chainlink VRF.

    uint256 public immutable i_interval; // Interval in seconds between price updates.

    uint256 private s_lastTimeStamp; // Timestamp of the last price update.
    uint256 private s_lastRequestId; // Stores the last VRF request ID.

    uint256 private s_subscriptionId; // Chainlink VRF subscription ID.
    uint16 private s_requestConfirmations; // Number of confirmations required for VRF request.
    uint32 private s_callbackGasLimit; // Gas limit for the VRF callback.

    bytes32 private s_keyHash; // Key hash for the Chainlink VRF request.

    uint256[] private s_lastPrices; // Stores the historical prices of the collateral token.

    MockV3AggregatorOwnable private s_priceFeed; // Mock price feed contract used for updating collateral price.

    /////////////////////////////
    ////////// EVENTS ///////////
    /////////////////////////////

    /**
     * @dev Event emitted when a new request for a random number is sent.
     * @param requestId The ID of the VRF request.
     * @param numWords The number of random words requested.
     */
    event RequestSent(uint256 indexed requestId, uint32 indexed numWords);

    /**
     * @dev Event emitted when a new random price is generated and stored.
     * @param requestId The ID of the fulfilled VRF request.
     * @param randomWord The raw random number received from Chainlink VRF.
     */
    event RequestFulfilled(uint256 indexed requestId, uint256 indexed randomWord);

    /////////////////////////////
    //////// CONSTRUCTOR ////////
    /////////////////////////////

    /**
     * @dev Initializes the contract with necessary Chainlink configurations and the mock price feed.
     * @param _vrfCoordinator Address of the Chainlink VRF Coordinator.
     * @param _subId Subscription ID for Chainlink VRF.
     * @param _updateInterval Time interval (in seconds) between price updates.
     * @param _priceFeedAddress Address of the mock Chainlink price feed.
     * @param _keyHash Key hash used to identify the VRF job.
     * @param _requestConfirmations Number of block confirmations required for randomness.
     * @param _callbackGasLimit Maximum gas allowed for the VRF callback function.
     */
    constructor(
        address _vrfCoordinator,
        uint256 _subId,
        uint256 _updateInterval,
        address _priceFeedAddress,
        bytes32 _keyHash,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_interval = _updateInterval;
        s_lastTimeStamp = block.timestamp;

        s_vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        s_subscriptionId = _subId;
        s_keyHash = _keyHash;
        s_requestConfirmations = _requestConfirmations;
        s_callbackGasLimit = _callbackGasLimit;

        s_priceFeed = MockV3AggregatorOwnable(_priceFeedAddress);
    }

    /////////////////////////////
    //////// CHAINLINK /////////
    /////////////////////////////

    /**
     * @notice Check if the upkeep (scheduled action) needs to be performed.
     * @dev This function is called by Chainlink Automation nodes to determine whether `performUpkeep`
     *      should be executed.
     * @return upkeepNeeded A boolean indicating if an update is required.
     * @return performData Encoded data that will be passed to `performUpkeep` (unused here).
     */
    function checkUpkeep(bytes calldata /* checkData */ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        upkeepNeeded = (block.timestamp - s_lastTimeStamp) > i_interval;
    }

    /**
     * @notice Requests a new random number from Chainlink VRF to generate a new collateral price.
     * @dev This function is automatically called by Chainlink Automation when `checkUpkeep` returns true.
     */
    function performUpkeep(bytes calldata /* performData */ ) external override {
        if ((block.timestamp - s_lastTimeStamp) > i_interval) {
            uint256 requestId = s_vrfCoordinator.requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: s_keyHash,
                    subId: s_subscriptionId,
                    requestConfirmations: s_requestConfirmations,
                    callbackGasLimit: s_callbackGasLimit,
                    numWords: NUM_WORDS,
                    extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
                })
            );

            s_lastTimeStamp = block.timestamp;
            s_lastRequestId = requestId;
            emit RequestSent(requestId, NUM_WORDS);
        } else {
            revert TestnetPriceRandomUpdate__NotEnoughTimePassed();
        }
    }

    /**
     * @notice Callback function that receives random words from Chainlink VRF.
     * @dev Updates the price of the collateral token based on the random number received.
     * @param requestId The ID of the VRF request.
     * @param randomWords An array containing the generated random word(s).
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Transform the random number into a price value between 0.00000001 and 1000 (inclusive)
        uint256 newPrice = (randomWords[0] % MAX_PRICE) + 1;
        s_lastPrices.push(newPrice);

        // Update the mock Chainlink price feed with the new price
        s_priceFeed.updateAnswer(int256(newPrice));
        emit RequestFulfilled(requestId, randomWords[0]);
    }

    /////////////////////////////
    ////////// GETTERS //////////
    /////////////////////////////

    /**
     * @dev Returns the timestamp of the last price update.
     */
    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    /**
     * @dev Returns a stored price by its index in the history array.
     */
    function getLastPricesByIndex(uint256 _index) external view returns (uint256) {
        return s_lastPrices[_index];
    }

    /**
     * @dev Returns the ID of the last Chainlink VRF request.
     */
    function getLastRequestId() external view returns (uint256) {
        return s_lastRequestId;
    }

    /**
     * @dev Returns the address of the price feed contract.
     */
    function getPriceFeedAddress() external view returns (address) {
        return address(s_priceFeed);
    }
}
