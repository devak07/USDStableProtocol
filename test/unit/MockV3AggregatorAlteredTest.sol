// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockV3AggregatorAltered} from "test/mocks/MockV3AggregatorAltered.sol";

/**
 * @title MockV3AggregatorAlteredTest
 * @dev Test suite for the MockV3AggregatorAltered contract.
 */
contract MockV3AggregatorAlteredTest is Test {
    ////////////////////////////
    //////// VARIABLES /////////
    ////////////////////////////

    int256 constant INITIAL_ANSWER = 1e8; // Initial price feed answer
    int256 constant WRONG_ANSWER = -1; // Invalid price data
    int256 constant GOOD_ANSWER = 10e8; // Valid price data
    uint80 constant ROUND_ID = 1; // Default round ID
    uint8 constant DECIMALS = 8; // Decimals for price feed

    MockV3AggregatorAltered private mockV3AggregatorAltered;

    ////////////////////////////
    ///////// SETUP ////////////
    ////////////////////////////

    /**
     * @dev Setup function executed before each test.
     * Deploys a new instance of MockV3AggregatorAltered.
     */
    function setUp() external {
        mockV3AggregatorAltered = new MockV3AggregatorAltered(DECIMALS, INITIAL_ANSWER);
    }

    /////////////////////////////
    ///////// FUNCTIONS /////////
    /////////////////////////////

    /**
     * @dev Test that updating the answer with invalid data reverts.
     */
    function testUpdateAnswerWithWrongData() external {
        vm.expectRevert(MockV3AggregatorAltered.MockV3AggregatorAltered__WrongPriceData.selector);
        mockV3AggregatorAltered.updateAnswer(WRONG_ANSWER);
    }

    /**
     * @dev Test that updating round data with invalid data reverts.
     */
    function testUpdateRoundDataWithWrongData() external {
        vm.expectRevert(MockV3AggregatorAltered.MockV3AggregatorAltered__WrongPriceData.selector);
        mockV3AggregatorAltered.updateRoundData(ROUND_ID, WRONG_ANSWER, block.timestamp, block.timestamp);
    }

    /**
     * @dev Test updating the price feed answer with valid data.
     */
    function testUpdateAnswer() external {
        mockV3AggregatorAltered.updateAnswer(GOOD_ANSWER);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mockV3AggregatorAltered.getRoundData(ROUND_ID + 1);

        assertEq(roundId, ROUND_ID + 1);
        assertEq(answer, GOOD_ANSWER);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, ROUND_ID + 1);
    }

    /**
     * @dev Test updating the round data with valid values.
     */
    function testUpdateRoundData() external {
        mockV3AggregatorAltered.updateRoundData(ROUND_ID, GOOD_ANSWER, block.timestamp, block.timestamp);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mockV3AggregatorAltered.latestRoundData();

        assertEq(roundId, ROUND_ID);
        assertEq(answer, GOOD_ANSWER);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, ROUND_ID);
    }

    /**
     * @dev Test retrieving the description of the mock aggregator.
     */
    function testDescription() external view {
        assertEq(
            abi.encode(mockV3AggregatorAltered.description()), abi.encode("v0.6/test/mock/MockV3AggregatorAltered.sol")
        );
    }
}
