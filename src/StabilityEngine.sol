// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {CollateralToken} from "src/CollateralToken.sol";

/**
 * @title StabilityEngine
 * @author Andrzej Knapik (GitHub: devak07)
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
 *
 * @notice System can only work if price of token is greater than 0.00000001$
 *
 * @notice System can't mint fractional tokens, so users can't redeem less than 1 token and can receive less than they
 *         deposited up to the value of 1 token.
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
    AggregatorV3Interface private immutable i_priceFeed;

    /////////////////////////////
    ////////// EVENTS ///////////
    /////////////////////////////

    /**
     * @dev Event emitted when collateral tokens are transferred from a user to the contract.
     * @param userAddress The address of the user who deposited collateral.
     * @param amount The amount of collateral tokens transferred.
     */
    event CollateralDeposited(address indexed userAddress, uint256 amount);

    /**
     * @dev Event emitted when collateral tokens are redeemed by a user.
     * @param userAddress The address of the user who redeemed collateral.
     * @param amount The amount of collateral tokens redeemed.
     */
    event CollateralRedeemed(address indexed userAddress, uint256 amount);

    /////////////////////////////
    ///////// MODIFIERS /////////
    /////////////////////////////

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
     * @dev Constructor for the StabilityEngine contract. Initializes the collateral token instance and price feed.
     * @param _priceFeed The address of the Chainlink price feed contract for the collateral token.
     */
    constructor(address _priceFeed) {
        i_collateralToken = new CollateralToken(); // Deploys a new instance of the CollateralToken contract.
        i_priceFeed = AggregatorV3Interface(_priceFeed);
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
        nonReentrant
        moreThanZero(_amountOfCollateralTokens)
    {
        _depositAndBurnCollateral(_amountOfCollateralTokens);
    }

    /**
     * @dev Function for users to redeem collateral in exchange for collateral tokens, which are minted.
     * The corresponding amount of dollars is updated based on the collateral value.
     * This ensures that the value of collateral is always redeemable in terms of USD,
     * regardless of the token price fluctuations.
     * @param _valueInDollars The amount of collateral in USD to redeem.
     */
    function redeemCollateral(uint256 _valueInDollars) public nonReentrant moreThanZero(_valueInDollars) {
        _mintAndTransferCollateralToken(_valueInDollars);
    }

    //////////////////////////////
    ///// INTERNAL FUNCTIONS /////
    //////////////////////////////

    /**
     * @dev Internal function that handles minting collateral tokens and transferring them to the user.
     * It also adjusts the user's USD-equivalent balance based on the value of the redeemed collateral.
     * @param _valueInDollars The amount of collateral in USD to redeem.
     */
    function _mintAndTransferCollateralToken(uint256 _valueInDollars) internal {
        if (s_dollars[msg.sender] < _valueInDollars) {
            revert StabilityEngine__InfufficientBalance();
        }
        uint256 amountToMint = _getAmountOfTokens(_valueInDollars);
        i_collateralToken.mint(msg.sender, amountToMint);
        _changeValueInUsd(msg.sender, false, amountToMint);

        emit CollateralRedeemed(msg.sender, amountToMint);
    }

    /**
     * @dev Internal function for depositing and burning collateral tokens.
     * The deposited collateral is burned and the user's balance is updated accordingly.
     * @param _amountOfCollateral The amount of collateral tokens to deposit and burn.
     */
    function _depositAndBurnCollateral(uint256 _amountOfCollateral) internal {
        _transferFrom(msg.sender, address(this), address(i_collateralToken), _amountOfCollateral);
        i_collateralToken.burn(_amountOfCollateral);
        _changeValueInUsd(msg.sender, true, _amountOfCollateral);

        emit CollateralDeposited(msg.sender, _amountOfCollateral);
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
            revert StabilityEngine__TransferFailed();
        }
    }

    /**
     * @dev Internal function to update the user's USD balance when collateral tokens are deposited or redeemed.
     * @param _user The address of the user whose balance is being updated.
     * @param _action Indicates whether tokens are being deposited (true) or redeemed (false).
     * @param _amountOfCollateralTokens The amount of collateral tokens to use for the update.
     */
    function _changeValueInUsd(address _user, bool _action, uint256 _amountOfCollateralTokens) internal {
        uint256 _amountInUsd = _getValueInUsd(_amountOfCollateralTokens);

        if (_action) {
            s_dollars[_user] += _amountInUsd;
        } else {
            s_dollars[_user] -= _amountInUsd;
        }
    }

    /////////////////////////////
    // INTERNAL VIEW FUNCTIONS //
    /////////////////////////////

    /**
     * @dev Internal function that converts the collateral amount to its USD equivalent.
     * @param _amountOfCollateral The amount of collateral to convert to USD.
     * @return The USD equivalent of the collateral amount.
     */
    function _getValueInUsd(uint256 _amountOfCollateral) internal view returns (uint256) {
        uint256 price = _getLastPriceOfCollateralTokenWithoutPrecision() * PRECISION_TO_ADD;
        return ((price * _amountOfCollateral) / PRECISION);
    }

    /**
     * @dev Internal function to calculate how many tokens are needed to match a given USD value.
     * @param _valueInUsd The value in USD for which to calculate the required token amount.
     * @return The number of tokens needed to match the specified USD value.
     */
    function _getAmountOfTokens(uint256 _valueInUsd) internal view returns (uint256) {
        uint256 priceWithPrecision = _getLastPriceOfCollateralTokenWithoutPrecision() * PRECISION_TO_ADD;
        return ((_valueInUsd * PRECISION * PRECISION) / priceWithPrecision) / PRECISION;
    }

    /**
     * @dev Internal function that retrieves the latest price of the collateral token from the oracle.
     * The returned value does not include precision adjustments.
     * @return The raw price of the collateral token.
     */
    function _getLastPriceOfCollateralTokenWithoutPrecision() internal view returns (uint256) {
        (, int256 priceWithoutPrecision,,,) = AggregatorV3Interface(i_priceFeed).latestRoundData();
        return uint256(priceWithoutPrecision);
    }

    /////////////////////////////
    ////////// GETTERS //////////
    /////////////////////////////

    /**
     * @dev Returns the address of the collateral token contract.
     */
    function getCollateralTokenAddress() external view returns (address) {
        return address(i_collateralToken);
    }

    /**
     * @dev Returns the USD-equivalent balance of the user.
     */
    function getDollarsAmount(address _user) public view returns (uint256) {
        return s_dollars[_user];
    }

    /**
     * @dev Returns the address of the price feed contract.
     */
    function getPriceFeedAddress() external view returns (address) {
        return address(i_priceFeed);
    }

    /**
     * @dev Returns the USD value of 1 collateral token based on the current oracle price.
     */
    function getTokenValue() external view returns (uint256) {
        return _getValueInUsd(1);
    }

    /**
     * @dev Returns the raw price of the collateral token from the oracle without precision adjustments.
     */
    function getFullTokenValue() external view returns (uint256) {
        return _getLastPriceOfCollateralTokenWithoutPrecision();
    }

    ///////////////////////////////////////////////////////////////////////////////////
    /////////// THIS FUNCTION IS ONLY FOR TESTING AND PROJECT PRESENTATION ////////////
    // IF YOU LEAVE THIS FUNCTION AVAILABLE IN PRODUCTION, YOU WILL LOOSE YOUR MONEY //
    ///////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev This function is used to present token on testnet or local chain.
     * It gives ten collateral tokens to user that calls this function to use it later in this protocol.
     */
    function getTenTokens() external {
        i_collateralToken.mint(msg.sender, 10);
    }
}
