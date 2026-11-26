// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "./IPayable.sol";
import { AbstractPayer } from "./AbstractPayer.sol";

/// @title Base for contracts that receive Reactive Network callbacks on a
///        destination chain.
/// @notice A callback is authentic only when both checks pass: the immediate
///        caller is this chain's callback proxy (inherited
///        `onlyServiceProvider`), and the sender address the proxy injected
///        into the payload's first argument is the reactive contract this
///        contract was built to serve (`onlyCallbackSender`).
///        Original implementation, written for this project against the
///        Reactive Omni specification (dev.reactive.network).
abstract contract AbstractCallback is AbstractPayer {
    /// @notice The injected callback sender is not the authorized one.
    error CallbackNotAuthorized(address sender_, address expectedSender_);

    /// @notice The reactive contract allowed to drive this contract's
    ///         callbacks. Immutable: a wrong value means redeploying.
    address public immutable _CALLBACK_SENDER;

    /// @param callbackProxy_ This chain's callback proxy (the service
    ///        provider that delivers and bills callbacks).
    /// @param callbackSender_ The reactive contract to authorize.
    constructor(IPayable callbackProxy_, address callbackSender_) AbstractPayer(callbackProxy_) {
        _CALLBACK_SENDER = callbackSender_;
    }

    /// @notice Guards a callback method with the injected sender address.
    modifier onlyCallbackSender(address callbackSender_) {
        _onlyCallbackSender(callbackSender_);
        _;
    }

    function _onlyCallbackSender(address callbackSender_) internal view {
        if (callbackSender_ != _CALLBACK_SENDER) {
            revert CallbackNotAuthorized(callbackSender_, _CALLBACK_SENDER);
        }
    }
}
