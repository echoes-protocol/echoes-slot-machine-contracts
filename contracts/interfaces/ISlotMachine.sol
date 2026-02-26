// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISlotMachine {
    // Events

    /**
     * @notice Emitted when the contract's accepted token is updated.
     * @param previousToken The address of the token that was previously accepted.
     * @param newToken The address of the token that replaces the previous token.
     */
    event TokenUpdated(address indexed previousToken, address indexed newToken);

    /**
     * @notice Emitted when a user deposits tokens into the contract.\
     * @param txId A unique transaction identifier for this deposit.
     * @param user The address of the account that made the deposit.
     * @param amount The amount of tokens deposited (in the token's smallest unit).
     * @param token The ERC20 token contract address that was deposited.
     * @param dType A uint8 value representing the deposit type or category.
     */
    event Deposited(
        uint256 txId,
        address indexed user,
        uint256 amount,
        address indexed token,
        uint8 dType
    );

    /**
     * @notice Emitted when an administrative withdrawal is performed from the contract.
     * @param caller The address that initiated the withdrawal (indexed).
     * @param amount The amount withdrawn, expressed in the token's smallest unit.
     * @param to The address that received the withdrawn funds (indexed).
     * @param tokenAddress The address of the token that was withdrawn; use the zero address to indicate native currency (e.g., ETH).
     */
    event AdminWithdraw(
        address indexed caller,
        uint256 amount,
        address indexed to,
        address tokenAddress
    );

    /**
     * @notice Emitted when a user withdraws funds from the contract.
     * @dev Indicates a successful withdrawal operation. For native ETH withdrawals, `token` will be address(0).
     * @param user The address of the user who received the withdrawn funds (indexed).
     * @param amount The amount withdrawn (in wei for ETH or in token units for ERC20).
     * @param token The token contract address withdrawn; use address(0) to denote native ETH.
     */
    event Withdrawn(address indexed user, uint256 amount, address token);

    // Custom Errors

    /// @notice Thrown when attempting to use a zero address
    error ZeroAddress();
}
