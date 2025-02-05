// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Deploy} from "script/Deploy.s.sol";
import {TestnetPriceRandomUpdate} from "src/TestnetPriceRandomUpdate.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockV3AggregatorOwnable} from "test/mocks/MockV3AggregatorOwnable.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {NETWORK_IDS} from "script/Config.s.sol";

/**
 * @author Andrzej Knapik (GitHub: akdev07)
 * @title TestnetPriceRandomUpdateTest
 * @dev This contract contains unit tests for the `TestnetPriceRandomUpdate` contract.
 * It tests the functionality of the price update mechanism, ensuring that upkeep, randomness, and price updates behave correctly.
 */
contract TestnetPriceRandomUpdateTest is Test, NETWORK_IDS {
    ///////////////////////////////
    /////////// ERRORS ////////////
    ///////////////////////////////
    error TestnetPriceRandomUpdate__NotEnoughTimePassed();

    ///////////////////////////////
    /////// STATE VARIABLES ///////
    ///////////////////////////////

    address vrfCoordinatorAddress;
    uint256 subscriptionId;
    TestnetPriceRandomUpdate testnetPriceRandomUpdate;
    address priceFeedAddress;
    bytes constant BYTES_ZERO = bytes("0");
    uint256 constant ONE = 1;
    StabilityEngine stabilityEngine;

    ///////////////////////////////
    ////////// MODIFIERS //////////
    ///////////////////////////////

    modifier skipOnOtherThanAnvilNetwork() {
        if (block.chainid != ANVIL_CHAINID) {
            return;
        }
        _;
    }

    modifier timePassed() {
        vm.warp(block.timestamp + 1 days + 1);
        vm.roll(block.number + 1);
        _;
    }

    ///////////////////////////////
    /////// SETUP FUNCTION ////////
    ///////////////////////////////

    /**
     * @dev Setup function to deploy the required contracts before each test.
     */
    function setUp() external {
        Deploy deploy = new Deploy();
        (stabilityEngine, vrfCoordinatorAddress, testnetPriceRandomUpdate) = deploy.run();
    }

    ///////////////////////////////
    //////// TEST FUNCTIONS ///////
    ///////////////////////////////

    /**
     * @dev Test: Check that `checkUpkeep` returns false initially.
     * It expects the upkeep to return false since no time has passed.
     */
    function testCheckUpKeepReturnsFalse() external view skipOnOtherThanAnvilNetwork {
        (bool result,) = testnetPriceRandomUpdate.checkUpkeep(BYTES_ZERO);
        assertEq(result, false);
    }

    /**
     * @dev Test: Check that `checkUpkeep` returns true after time has passed.
     * It ensures the upkeep can return true after the required time has passed.
     */
    function testCheckUpKeepReturnsTrue() external skipOnOtherThanAnvilNetwork timePassed {
        (bool result,) = testnetPriceRandomUpdate.checkUpkeep(BYTES_ZERO);
        assertEq(result, true);
    }

    /**
     * @dev Test: Ensure `performUpkeep` reverts if not enough time has passed.
     * It expects a revert with `TestnetPriceRandomUpdate__NotEnoughTimePassed` error.
     */
    function testPerformUpKeepReverts() external skipOnOtherThanAnvilNetwork {
        vm.expectRevert(TestnetPriceRandomUpdate__NotEnoughTimePassed.selector);
        testnetPriceRandomUpdate.performUpkeep(BYTES_ZERO);
    }

    /**
     * @dev Test: Ensure `performUpkeep` sends a request when enough time has passed.
     * It checks the emitted event to ensure that the request is made correctly.
     */
    function testPerformUpKeepSendsRequest() external skipOnOtherThanAnvilNetwork timePassed {
        vm.recordLogs();
        testnetPriceRandomUpdate.performUpkeep(BYTES_ZERO);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assert(logs.length == 2);
        assert(logs[1].topics[0] == keccak256("RequestSent(uint256,uint32)"));
        assert(logs[1].topics[1] == bytes32(bytes(abi.encodePacked(ONE))));
    }

    /**
     * @dev Test: Ensure `fulfillRandomWords` correctly updates the price in `StabilityEngine`.
     * It checks that the `StabilityEngine`'s token value is updated after the random words are fulfilled.
     */
    function testFulfillRandomWords() external skipOnOtherThanAnvilNetwork timePassed {
        testnetPriceRandomUpdate.performUpkeep(BYTES_ZERO);
        VRFCoordinatorV2_5Mock(vrfCoordinatorAddress).fulfillRandomWords(
            testnetPriceRandomUpdate.getLastRequestId(), address(testnetPriceRandomUpdate)
        );

        assertEq(stabilityEngine.getFullTokenValue(), testnetPriceRandomUpdate.getLastPricesByIndex(0));
    }
}
