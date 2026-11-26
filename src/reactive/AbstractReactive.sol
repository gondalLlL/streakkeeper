// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "./ISystemContract.sol";
import { IReactive } from "./IReactive.sol";
import { AbstractPayer } from "./AbstractPayer.sol";

/// @title Base for reactive contracts.
/// @notice Supplies the system contract handle, the topic wildcard used by
///        subscriptions, and the `onlySystem` guard for `react()`.
///        Original implementation, written for this project against the
///        Reactive Omni specification (dev.reactive.network).
abstract contract AbstractReactive is AbstractPayer, IReactive {
    /// @notice The Reactive system contract — same address on Reactive
    ///         mainnet and on the Lasna testnet.
    ISystemContract internal constant SYSTEM = ISystemContract(payable(0x8888888888888888888888888888888888888888));

    /// @notice Wildcard value for any topic position of a subscription.
    uint256 internal constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    constructor() AbstractPayer(SYSTEM) {}

    /// @notice Guards methods (above all `react()`) that only the system
    ///         contract may call.
    modifier onlySystem() {
        _onlyServiceProvider();
        _;
    }
}
