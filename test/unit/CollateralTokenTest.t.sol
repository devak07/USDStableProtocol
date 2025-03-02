// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {CollateralToken} from "src/CollateralToken.sol";
import {StabilityEngine} from "src/StabilityEngine.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @author Andrzej Knapik (GitHub: devak07)
 * @title CollateralTokenTest
 * @dev A test suite for the CollateralToken contract. This contract is designed for use with Forge (foundry).
 * It includes tests for ownership, minting, burning, and pause functionality, ensuring the correctness of the contract's behavior.
 *
 */
contract CollateralTokenTest is Test {
    ////////////////////////////
    //////// VARIABLES /////////
    ////////////////////////////

    CollateralToken collateralToken; // Instance of the CollateralToken contract.
    StabilityEngine stabilityEngine; // Instance of the StabilityEngine contract (deployed via Deploy).

    address owner; // The owner of the CollateralToken contract (the StabilityEngine contract address).

    ////////////////////////////
    ///////// ERRORS ///////////
    ////////////////////////////

    error CollateralToken__InvalidAddress(); // Error for invalid addresses (address(0)).
    error CollateralToken__MoreThanZero(); // Error for zero-value minting/burning.
    error OwnableUnauthorizedAccount(address account); // Error for unauthorized actions.
    error EnforcedPause(); // Error for attempting actions while paused.

    ////////////////////////////
    ///////// EVENTS ///////////
    ////////////////////////////

    event TokensMinted(address indexed to, uint256 amount); // Event emitted when tokens are minted.
    event TokensBurned(uint256 amount); // Event emitted when tokens are burned.

    ////////////////////////////
    //////// CONSTANTS /////////
    ////////////////////////////

    address USER_1 = makeAddr("USER_1"); // Simulated user address for testing.

    ////////////////////////////
    //////// MODIFIERS /////////
    ////////////////////////////

    /**
     * @notice Ensures the function executes as the owner of the CollateralToken contract.
     */
    modifier prankedWithOwner() {
        vm.startPrank(owner);
        _;
    }

    ////////////////////////////
    ///////// SETUP ////////////
    ////////////////////////////

    /**
     * @notice Deploys the StabilityEngine contract and retrieves the CollateralToken instance.
     * Sets the `owner` to the StabilityEngine contract address.
     */
    function setUp() external {
        Deploy deploy = new Deploy();
        stabilityEngine = deploy.run();
        collateralToken = CollateralToken(stabilityEngine.getCollateralTokenAddress());
        owner = address(stabilityEngine);
    }

    ////////////////////////////
    ///////// TESTS ////////////
    ////////////////////////////

    /**
     * @notice Tests that the CollateralToken's owner is correctly set.
     */
    function testOwnership() external view {
        assertEq(owner, collateralToken.owner());
    }

    /**
     * @notice Tests the minting functionality when invoked by the owner.
     * Verifies that the event is emitted and the user's balance is updated.
     */
    function testMintingWorks() external prankedWithOwner {
        vm.recordLogs();
        collateralToken.mint(USER_1, 1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(2, logs.length);
        assertEq(logs[1].topics[0], keccak256("TokensMinted(address,uint256)"));
        assertEq(logs[1].data, abi.encode(1));
        assertEq(1, collateralToken.balanceOf(USER_1));
    }

    /**
     * @notice Tests that minting with a zero value reverts with the correct error.
     */
    function testMintingWithZeroValue() external prankedWithOwner {
        vm.expectRevert(CollateralToken__MoreThanZero.selector);
        collateralToken.mint(USER_1, 0);
    }

    /**
     * @notice Tests that minting to the zero address reverts with the correct error.
     */
    function testMintingWithZeroAddress() external prankedWithOwner {
        vm.expectRevert(CollateralToken__InvalidAddress.selector);
        collateralToken.mint(address(0), 1);
    }

    /**
     * @notice Tests that minting as a non-owner reverts with the correct error.
     */
    function testMintingAsNotOwner() external {
        vm.startPrank(USER_1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER_1));
        collateralToken.mint(USER_1, 1);
    }

    /**
     * @notice Tests the burning functionality when invoked by the owner.
     */
    function testBurning() external prankedWithOwner {
        collateralToken.mint(owner, 1);

        vm.recordLogs();
        collateralToken.burn(1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(2, logs.length);
        assertEq(logs[1].topics[0], keccak256("TokensBurned(uint256)"));
        assertEq(logs[1].data, abi.encode(1));
        assertEq(0, collateralToken.balanceOf(owner));
    }

    /**
     * @notice Tests that burning with a zero value reverts with the correct error.
     */
    function testBurningWithZeroValue() external prankedWithOwner {
        vm.expectRevert(CollateralToken__MoreThanZero.selector);
        collateralToken.burn(0);
    }

    /**
     * @notice Tests that burning as a non-owner reverts with the correct error.
     */
    function testBurningAsNotOwner() external {
        vm.startPrank(USER_1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER_1));
        collateralToken.burn(1);
    }
}
