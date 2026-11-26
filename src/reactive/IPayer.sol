// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title Interface a contract exposes so its service provider (the Reactive
///        system contract, or a callback proxy) can collect payment from it.
/// @notice Written from the Reactive Omni interface specification
///         (dev.reactive.network) for this project.
interface IPayer {
    /// @notice Accepts funding. A contract's balance is what its provider
    ///         draws on, so topping up is always permissionless.
    receive() external payable;

    /// @notice Pays the calling service provider the given amount out of this
    ///         contract's own balance. Must reject callers that are not the
    ///         contract's service provider.
    /// @param amount_ Amount the provider is collecting.
    function pay(uint256 amount_) external;
}
