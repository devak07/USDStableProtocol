// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {CollateralToken} from "src/CollateralToken.sol";

/**
 * @title StabilityEngine
 * @author Andrzej Knapik (devak07)
 *
 * @dev This contract is designed to manage a collateralized system where users can deposit collateral,
 *      and the system ensures that their deposits retain a stable value, even if the price of the collateral
 *      token fluctuates. The key objective is to maintain a 1:1 ratio between deposited collateral (in USD terms)
 *      and the collateral token. This means that when a user deposits $1 worth of collateral, they should be able
 *      to redeem $1 worth of collateral tokens, irrespective of the current price of the token.
 *
 * @notice This system operates on a 1:1 collateralization model. However, it is important to note that if the
 *         total market capitalization of the collateral token falls below the value of the collateral in the system,
 *         it may create an issue where the system cannot mint enough tokens to maintain the 1:1 ratio.
 *         For example, if the total market cap is $1, but a user wants to redeem $1 worth of collateral,
 *         even minting an infinite number of tokens would not solve the problem, as the system would be insolvent.
 *         This scenario is unlikely but is still a known issue.
 *         A future update will introduce fees or commissions to address this issue in case it arises, though it remains
 *         a rare and improbable occurrence.
 */
contract StabilityEngine is ReentrancyGuard {
    /////////////////////////////
    ////////// ERRORS ///////////
    /////////////////////////////

    /**
     * @dev Error triggered when an invalid address (0x0 address) is provided.
     */
    error StabilityEngine__InvalidAddress();

    /**
     * @dev Error triggered when the amount provided is less than or equal to zero.
     */
    error StabilityEngine__MustBeMoreThanZero();

    /**
     * @dev Error triggered when a transfer operation fails.
     */
    error StabilityEngine__TransferFailed();

    /**
     * @dev Error triggered when the fetched price of collateral is invalid.
     */
    error StabilityEngine__InvalidPrice();

    /**
     * @dev Error triggered when a user has insufficient balance in the system.
     */
    error StabilityEngine__InfufficientBalance();

    /////////////////////////////
    ////// STATE VARIABLES //////
    /////////////////////////////

    uint256 private constant PRECISION_TO_ADD = 1e10; // Precision factor for price adjustments.
    uint256 private constant PRECISION = 1e18; // Base precision used throughout the system.

    CollateralToken private immutable i_collateralToken; // Collateral token instance.

    mapping(address userAddress => uint256 dollarsAmount) s_dollars; // Mapping to track each user's USD-equivalent collateral amount.

    /////////////////////////////
    ////////// EVENTS ///////////
    /////////////////////////////

    /**
     * @dev Event emitted when collateral tokens are transferred from a user to the contract.
     * @param userAddress The address of the user who deposited collateral.
     * @param amount The amount of collateral tokens transferred.
     */
    event CollateralTransfered(address indexed userAddress, uint256 amount);

    /////////////////////////////
    ///////// MODIFIERS /////////
    /////////////////////////////

    /**
     * @dev Modifier that checks if the provided address is valid (not the zero address).
     * Reverts if the address is invalid.
     * @param _address The address to check.
     */
    modifier isValidAddress(address _address) {
        if (_address == address(0)) {
            revert StabilityEngine__InvalidAddress();
        }
        _;
    }

    /**
     * @dev Modifier that ensures the provided amount is greater than zero.
     * Reverts if the amount is zero or negative.
     * @param _amount The amount to check.
     */
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert StabilityEngine__MustBeMoreThanZero();
        }
        _;
    }

    /////////////////////////////
    //////// CONSTRUCTOR ////////
    /////////////////////////////

    /**
     * @dev Constructor for the StabilityEngine contract. Initializes the collateral token instance.
     */
    constructor() {
        i_collateralToken = new CollateralToken(); // Deploys a new instance of the CollateralToken contract.
    }

    /////////////////////////////
    ///////// FUNCTIONS /////////
    /////////////////////////////

    /**
     * @dev Function for users to deposit collateral tokens into the system.
     * The tokens are burned as part of the collateralization process. The system ensures that the value of the deposit
     * remains stable in USD terms, so if a user deposits $1 worth of collateral, they can redeem $1 worth of collateral
     * later, regardless of the current price of the token.
     * @param _amountOfCollateralTokens The amount of collateral tokens to deposit.
     */
    function depositCollateral(uint256 _amountOfCollateralTokens)
        public
        nonReentrant // Prevents reentrancy attacks.
        moreThanZero(_amountOfCollateralTokens) // Ensures the deposit amount is greater than zero.
    {
        _depositAndBurnCollateral(_amountOfCollateralTokens); // Internal function for handling deposit and burning process.
    }

    /**
     * @dev Function for users to redeem collateral in exchange for collateral tokens, which are minted.
     * The corresponding amount of dollars is updated based on the collateral value.
     * This ensures that the value of collateral is always redeemable in terms of USD,
     * regardless of the token price fluctuations.
     * @param _valueInDollars The amount of collateral in USD to redeem.
     */
    function redeemCollateralAndBurnStability(uint256 _valueInDollars)
        public
        nonReentrant // Prevents reentrancy attacks.
        moreThanZero(_valueInDollars) // Ensures the value to redeem is greater than zero.
    {
        _mintAndTransferCollateralToken(_valueInDollars); // Internal function for minting collateral tokens and transferring them to the user.
    }

    //////////////////////////////
    ///// INTERNAL FUNCTIONS /////
    //////////////////////////////

    /**
     * @dev Internal function that handles minting collateral tokens and transferring them to the user.
     * It also adjusts the user's USD-equivalent balance based on the value of the redeemed collateral.
     * This ensures that when a user redeems collateral, they always receive collateral equivalent to the specified USD value.
     * @param _valueInDollars The amount of collateral in USD to redeem.
     */
    function _mintAndTransferCollateralToken(uint256 _valueInDollars) internal {
        uint256 amountToMint = _getAmountOfTokens(_valueInDollars); // Calculates the amount of collateral tokens to mint based on USD value.
        i_collateralToken.mint(msg.sender, amountToMint); // Mints the calculated amount of collateral tokens to the user's address.
        _changeValueInUsd(msg.sender, false, _valueInDollars); // Adjusts the user's USD balance.
    }

    /**
     * @dev Internal function for depositing and burning collateral tokens.
     * The deposited collateral is burned and the user's balance is updated accordingly.
     * This function ensures that the system maintains a 1:1 ratio between collateral value and USD value.
     * @param _amountOfCollateral The amount of collateral tokens to deposit and burn.
     */
    function _depositAndBurnCollateral(uint256 _amountOfCollateral) internal {
        _transferFrom(msg.sender, address(this), address(i_collateralToken), _amountOfCollateral); // Transfers collateral tokens from the user to the contract.

        i_collateralToken.burn(_amountOfCollateral); // Burns the deposited collateral tokens to reduce the total supply.

        _changeValueInUsd(msg.sender, true, _amountOfCollateral); // Updates the user's USD balance based on the collateral value.

        emit CollateralTransfered(msg.sender, _amountOfCollateral); // Emits an event for the collateral transfer.
    }

    /**
     * @dev Internal function for transferring tokens from one address to another.
     * If the transfer fails, an error is reverted.
     * @param _from The address to transfer tokens from.
     * @param _to The address to transfer tokens to.
     * @param _tokenAddress The address of the token to transfer.
     * @param _amountToTransfer The amount of tokens to transfer.
     */
    function _transferFrom(address _from, address _to, address _tokenAddress, uint256 _amountToTransfer) internal {
        bool success = IERC20(_tokenAddress).transferFrom(_from, _to, _amountToTransfer);
        if (!success) {
            revert StabilityEngine__TransferFailed(); // Reverts the transaction if the transfer fails.
        }
    }

    /**
     * @dev Internal function to update the user's USD balance when collateral tokens are deposited or redeemed.
     * The system ensures that the balance reflects the exact value of collateral in USD, maintaining a 1:1 ratio.
     * @param _user The address of the user whose balance is being updated.
     * @param _action Indicates whether tokens are being deposited (true) or redeemed (false).
     * @param _amountOfCollateralTokens The amount of collateral tokens to use for the update.
     */
    function _changeValueInUsd(address _user, bool _action, uint256 _amountOfCollateralTokens) internal {
        uint256 _amountInUsd = _getValueInUsd(_amountOfCollateralTokens); // Converts collateral value to USD.

        if (_action) {
            s_dollars[_user] += _amountInUsd; // Increases the user's balance for deposits.
        } else {
            s_dollars[_user] -= _amountInUsd; // Decreases the user's balance for redemptions.
        }
    }

    /////////////////////////////
    ////////// GETTERS //////////
    /////////////////////////////

    /**
     * @dev Internal function that converts the collateral amount to its USD equivalent.
     * The collateral's price is fetched from an oracle to get the current market price.
     * @param _amountOfCollateral The amount of collateral to convert to USD.
     * @return The USD equivalent of the collateral amount.
     */
    function _getValueInUsd(uint256 _amountOfCollateral) internal view returns (uint256) {
        uint256 price = _getLastPriceOfCollateralTokenWithoutPrecision() * PRECISION_TO_ADD; // Gets the price of the collateral token from the oracle.

        return ((price * _amountOfCollateral) / PRECISION); // Converts collateral amount to USD.
    }

    /**
     * @dev Internal function to calculate how many tokens are needed to match a given USD value.
     * This function uses the current collateral token price to determine the amount to mint or burn.
     * @param _valueInUsd The value in USD for which to calculate the required token amount.
     * @return The number of tokens needed to match the specified USD value.
     */
    function _getAmountOfTokens(uint256 _valueInUsd) internal view returns (uint256) {
        uint256 priceWithPrecision = _getLastPriceOfCollateralTokenWithoutPrecision() * PRECISION_TO_ADD; // Get price with precision.
        return ((_valueInUsd * PRECISION * PRECISION) / priceWithPrecision); // Calculates the token amount needed for the USD value.
    }

    /**
     * @dev Internal function that retrieves the latest price of the collateral token from the oracle.
     * The returned value does not include precision adjustments.
     * @return The raw price of the collateral token.
     */
    function _getLastPriceOfCollateralTokenWithoutPrecision() internal view returns (uint256) {
        (, int256 priceWithoutPrecision,,,) = AggregatorV3Interface(address(i_collateralToken)).latestRoundData();
        return uint256(priceWithoutPrecision); // Returns the raw price from the oracle.
    }
}
