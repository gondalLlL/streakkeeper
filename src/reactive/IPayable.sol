// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title Common interface shared by the Reactive system contract and the
///        destination-chain callback proxies: both can bill a contract and
///        both let a contract query what it owes.
/// @notice Written from the Reactive Omni interface specification
///         (dev.reactive.network) for this project.
interface IPayable {
    /// @notice The provider accepts plain payments (used to settle debt).
    receive() external payable;

    /// @notice Outstanding debt of a contract towards this provider.
    /// @param contract_ Contract to query.
    /// @return debt_ Amount currently owed.
    function debt(address contract_) external view returns (uint256 debt_);
}
