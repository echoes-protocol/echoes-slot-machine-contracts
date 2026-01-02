// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ISlotMachine} from "./interfaces/ISlotMachine.sol";

/**
 * @title SlotMachine
 * @notice contract that accepts echoes slot machine deposits in either native ETH or a ERC20 token.
 * @dev
 * Roles:
 * - DEFAULT_ADMIN_ROLE: full admin control (granted to the `admin` address on initialization).
 * - ADMIN_ROLE: can withdraw tokens or ETH from the contract.
 * - SETTER_ROLE: can update the token address accepted by the contract.
 * - PAUSER_ROLE: can pause contract operations.
 * - UNPAUSER_ROLE: can unpause contract operations.
 *
 * Events (emitted by contract operations):
 * - TokenUpdated(address previous, address current): emitted when the accepted token address is changed.
 * - Deposited(uint256 txId, address depositor, uint256 amount, address token, uint8 dType): emitted after a successful deposit.
 * - AdminWithdraw(address operator, uint256 amount, address to, address tokenAddr): emitted after an admin withdrawal.
 */

contract SlotMachine is
    ISlotMachine,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    // Structs and types

    /**
     * @dev Data structure recorded for each deposit.
     * @param txId Monotonic transaction identifier assigned to this deposit.
     * @param depositor Address that initiated the deposit.
     * @param amount Amount deposited (in wei for ETH or token units for ERC20).
     * @param dType A user-supplied deposit type byte (application-defined).
     */
    struct Deposit {
        uint256 txId;
        address depositor;
        uint256 amount;
        uint8 dType;
    }

    /* ─────────────────────────────── Roles ─────────────────────────────── */

    /// @notice Role that can withdraw tokens.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role that can update token address.
    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    /// @notice Role that can pause contract operations.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role that can unpause contract operations.
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    /* ──────────────────────── Storage Variables ──────────────────────── */

    /**
     * @notice Monotonic identifier of the last transaction processed by the slot machine.
     */
    uint256 public lastTxId;

    /// @notice Address of the token used for deposits.
    address public token;

    /// @notice Map a txId to its Deposit struct
    mapping(uint256 => Deposit) public deposits;

    /* ─────────────────────────── Initialization ─────────────────────────── */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the SlotMachine contract with the administrator and token addresses.
     * @param _admin Receives all admin roles (DEFAULT_ADMIN, SETTER, PAUSER, UNPAUSER).
     * @param _token Address of the accepted token
     */
    function initialize(address _admin, address _token) public initializer {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(UNPAUSER_ROLE, _admin);
        _grantRole(SETTER_ROLE, _admin);

        token = _token;
    }

    /**
     * @notice Update the token address used for deposits.
     * @dev Only callable by an account with SETTER_ROLE. Setting token to address(0) switches deposits to native ETH.
     * @param _token New token contract address to accept for ERC20 deposits, or address(0) to accept native ETH.
     */
    function setToken(address _token) external onlyRole(SETTER_ROLE) {
        address previous = token;
        token = _token;
        emit TokenUpdated(previous, _token);
    }

    /**
     * @notice Make a deposit to the contract
     * @dev When token is address(0), the function expects native ETH
     *      When token is non-zero, the function expects ERC20 token
     * @param _amount Amount to deposit (in wei for ETH or in token units for ERC20).
     * @param _dType Application-defined deposit type (uint8) attached to the deposit record.
     */
    function deposit(
        uint256 _amount,
        uint8 _dType
    ) external payable whenNotPaused {
        require(_amount > 0, "Invalid amount");

        if (token == address(0)) {
            // native ETH deposit
            uint256 beforeBalance = address(this).balance;
            require(msg.value == _amount, "Incorrect ETH amount");
            uint256 afterBalance = address(this).balance;
            require(
                afterBalance - beforeBalance == _amount,
                "ETH deposit mismatch"
            );
        } else {
            // ERC20 deposit
            IERC20 tokenContract = IERC20(token);
            uint256 beforeBalance = tokenContract.balanceOf(address(this));

            tokenContract.safeTransferFrom(msg.sender, address(this), _amount);

            uint256 afterBalance = tokenContract.balanceOf(address(this));
            require(
                afterBalance - beforeBalance == _amount,
                "Token transfer mismatch"
            );
        }

        lastTxId += 1;

        deposits[lastTxId] = Deposit({
            txId: lastTxId,
            depositor: msg.sender,
            amount: _amount,
            dType: _dType
        });

        emit Deposited(lastTxId, msg.sender, _amount, token, _dType);
    }

    /**
     * @notice Pause contract operations that are protected by whenNotPaused.
     * @dev Only callable by an account with PAUSER_ROLE.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract operations.
     * @dev Only callable by an account with UNPAUSER_ROLE.
     */
    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Withdraw ETH or ERC20 tokens from the contract to a specified recipient.
     * @dev Only callable by an account with ADMIN_ROLE. If `_tokenAddr` is address(0) an ETH transfer is performed,
     *      otherwise an ERC20 safeTransfer is executed.
     * @param _amount Amount to withdraw (in wei for ETH or in token units for ERC20).
     * @param _to Recipient address to receive the withdrawn funds; must not be zero address.
     * @param _tokenAddr Token contract address to withdraw; use address(0) to withdraw native ETH.
     */
    function adminWithdraw(
        uint256 _amount,
        address _to,
        address _tokenAddr
    ) external onlyRole(ADMIN_ROLE) {
        if (_to == address(0)) revert ZeroAddress();
        if (_tokenAddr == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_tokenAddr).safeTransfer(_to, _amount);
        }
        emit AdminWithdraw(msg.sender, _amount, _to, _tokenAddr);
    }
}
