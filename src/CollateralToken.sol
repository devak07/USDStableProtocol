// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CollateralToken
 * @author Andrzej Knapik (GitHub: devak07)
 *
 * @dev This contract implements a token that acts as collateral within a
 *      collateral-based financial system. It allows for minting, burning, and
 *      includes a pause mechanism in case of system issues. The system's
 *      integrity is maintained through the burning and minting processes,
 *      ensuring the stability of collateral and value tracking.
 *
 * @notice This contract is for portfolio purposes only and has
 *         not undergone any formal security audits. It is not recommended
 *         for use in a production environment.
 */
contract CollateralToken is ERC20Burnable, Ownable {
    ////////////////////////////
    ///////// ERRORS ///////////
    ////////////////////////////

    /**
     * @dev Error triggered when an invalid address is provided.
     */
    error CollateralToken__InvalidAddress();

    /**
     * @dev Error triggered when a non-positive amount is provided.
     */
    error CollateralToken__MoreThanZero();

    ////////////////////////////
    ///////// EVENTS ///////////
    ////////////////////////////

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(uint256 amount);

    ////////////////////////////
    //////// MODIFIERS /////////
    ////////////////////////////

    /**
     * @notice The `moreThanZero` modifier ensures that the provided amount
     *         is greater than zero. If not, the transaction will be reverted.
     * @param _amount The amount to check.
     */
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert CollateralToken__MoreThanZero();
        }
        _;
    }

    /**
     * @notice The `isValidAddress` modifier checks if the provided address
     *         is not the zero address. If it is, the transaction will be reverted.
     * @param _address The address to validate.
     */
    modifier isValidAddress(address _address) {
        if (_address == address(0)) {
            revert CollateralToken__InvalidAddress();
        }
        _;
    }

    ////////////////////////////
    /////// CONSTRUCTOR ////////
    ////////////////////////////

    constructor() ERC20("CollateralToken", "CT") Ownable(msg.sender) {}

    ////////////////////////////
    //////// FUNCTIONS /////////
    ////////////////////////////

    /**
     * @notice The `burn` function allows the owner to burn a specified
     *         amount of collateral tokens, reducing the total supply
     *         within the system.
     * @param _amountToBurn The amount of tokens to burn.
     */
    function burn(uint256 _amountToBurn) public override onlyOwner moreThanZero(_amountToBurn) {
        super.burn(_amountToBurn);
        emit TokensBurned(_amountToBurn);
    }

    /**
     * @notice The `mint` function allows the owner to mint new tokens and
     *         assign them to a specified address, ensuring that the total
     *         supply can increase to support the collateral requirements.
     * @param _to The address to receive the minted tokens.
     * @param _amountToMint The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amountToMint)
        public
        onlyOwner
        moreThanZero(_amountToMint)
        isValidAddress(_to)
    {
        _mint(_to, _amountToMint);
        emit TokensMinted(_to, _amountToMint);
    }

    ////////////////////////////
    ///// VIEW FUNCTIONS ///////
    ////////////////////////////
}
