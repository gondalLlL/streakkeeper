// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "./IPayable.sol";

/// @title Interface of the Reactive Network system contract (Omni).
/// @notice The system contract lives at the same address on Reactive mainnet
///         and on the Lasna testnet:
///         0x8888888888888888888888888888888888888888.
///         Written from the Reactive Omni interface specification
///         (dev.reactive.network) for this project.
interface ISystemContract is IPayable {
    /// @notice Supported callback configuration versions.
    enum CallbackVersion {
        V_1_0
    }

    /// @notice Callback configuration, version 1.0.
    /// @param chainId Destination chain the callback should be posted to.
    /// @param recipient Target contract on the destination chain.
    /// @param gasLimit Execution gas limit for the destination call.
    /// @param payload ABI-encoded function call for the recipient. Its first
    ///        argument must be an `address` placeholder: the network
    ///        overwrites the first 160 bits with the requesting reactive
    ///        contract's address so the recipient can authenticate it.
    struct CallbackConfiguration_V_1_0 {
        uint256 chainId;
        address recipient;
        uint64 gasLimit;
        bytes payload;
    }

    /// @notice Subscribes the caller to logs matching all six criteria.
    ///         Use chain id 0 / contract address(0) / REACTIVE_IGNORE topics
    ///         as wildcards; at least one criterion must be specific.
    function subscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external;

    /// @notice Removes a subscription matching all six arguments exactly.
    function unsubscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external;

    /// @notice Requests a callback using a version flag plus an ABI-encoded
    ///         configuration matching that version.
    function requestCallback(CallbackVersion version_, bytes memory config_) external;

    /// @notice Requests a version 1.0 callback, taking the typed struct.
    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 memory config_) external;
}
