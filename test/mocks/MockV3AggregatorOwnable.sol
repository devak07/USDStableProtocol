// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title MockV3AggregatorOwnable
 * @dev This contract is a mock implementation of the Chainlink AggregatorV3Interface.
 * It is designed to simulate the behavior of a Chainlink price feed for testing purposes.
 *
 * @notice This mock is used specifically for the Amoy testnet and the Anvil local chain.
 * It allows developers to test contracts that rely on price feeds without requiring a live Chainlink node.
 *
 * @notice On the Amoy testnet, this mock currently does not update prices automatically.
 * The owner is required to manually update the price using the `updateAnswer` function.
 *
 * @notice On the Ethereum mainnet or any production environment, this mock cannot be used
 * as it does not provide live price data. Contracts deployed on the mainnet or testnet require
 * a live Chainlink node for accurate price updates.
 */
contract MockV3AggregatorOwnable is AggregatorV3Interface, Ownable {
    uint256 public constant version = 4; // Version of the mock implementation.

    uint8 public decimals; // Number of decimals for the price data.
    int256 public latestAnswer; // Latest price answer.
    uint256 public latestTimestamp; // Timestamp of the latest answer.
    uint256 public latestRound; // Latest round ID.

    mapping(uint256 => int256) public getAnswer; // Mapping of round ID to price answer.
    mapping(uint256 => uint256) public getTimestamp; // Mapping of round ID to timestamp.
    mapping(uint256 => uint256) private getStartedAt; // Mapping of round ID to the start time.

    /**
     * @dev Constructor to initialize the mock with a specified number of decimals and an initial answer.
     * @param _decimals Number of decimals for the price data.
     * @param _initialAnswer Initial price answer to set.
     */
    constructor(uint8 _decimals, int256 _initialAnswer) Ownable(msg.sender) {
        decimals = _decimals;
        updateAnswer(_initialAnswer);
    }

    /**
     * @notice Updates the latest price answer manually.
     * @dev This function is restricted to the contract owner.
     * @param _answer The new price answer to set.
     */
    function updateAnswer(int256 _answer) public onlyOwner {
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    /**
     * @notice Updates round data manually.
     * @dev This function is restricted to the contract owner.
     * @param _roundId The round ID to update.
     * @param _answer The price answer for the round.
     * @param _timestamp The timestamp for the round.
     * @param _startedAt The start time for the round.
     */
    function updateRoundData(uint80 _roundId, int256 _answer, uint256 _timestamp, uint256 _startedAt)
        public
        onlyOwner
    {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    /**
     * @notice Fetches data for a specific round ID.
     * @param _roundId The round ID to fetch data for.
     * @return roundId The round ID.
     * @return answer The price answer for the round.
     * @return startedAt The start time for the round.
     * @return updatedAt The timestamp of the last update for the round.
     * @return answeredInRound The round ID where the answer was provided.
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
    }

    /**
     * @notice Fetches the latest round data.
     * @return roundId The latest round ID.
     * @return answer The latest price answer.
     * @return startedAt The start time for the latest round.
     * @return updatedAt The timestamp of the latest update.
     * @return answeredInRound The latest round ID where the answer was provided.
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    /**
     * @notice Returns the description of the mock contract.
     * @return A string description of the mock.
     */
    function description() external pure returns (string memory) {
        return "v0.6/test/mock/MockV3Aggregator.sol";
    }
}
