// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;


/// @title ITest -Just test
/// @author Grigory Morgachev
/// @notice This interface defines the functions, errors and events for the Test contract.
interface ITest {
    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------

    /// @dev Reverts if the contract is not active
    error ContractNotActive();

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    /// @notice For test: Emitted when a new utility contract template is registered.
    /// @param _contractAddress Address of the registered utility contract template.
    /// @param _fee Fee (in wei) required to deploy a clone of this contract.
    /// @param _isActive Whether the contract is active and deployable.
    /// @param _timestamp Timestamp when the contract was added.
    event NewContractAdded(address indexed _contractAddress, uint256 _fee, bool _isActive, uint256 _timestamp);
}