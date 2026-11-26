// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title The normalized form of an EVM log record that the Reactive system
///        contract hands to a reactive contract's `react()` function.
/// @notice Written from the Reactive Omni interface specification
///         (dev.reactive.network) for this project.
interface IReactive {
    /// @notice One origin-chain log, normalized by the network.
    /// @param chainId Chain the log was emitted on.
    /// @param contractAddress Contract that emitted the log.
    /// @param topic0 Topic 0 of the log (normally the event signature hash).
    /// @param topic1 Topic 1 of the log, or zero if the log had fewer topics.
    /// @param topic2 Topic 2 of the log, or zero if the log had fewer topics.
    /// @param topic3 Topic 3 of the log, or zero if the log had fewer topics.
    /// @param data ABI-encoded non-indexed event parameters, nothing else.
    /// @param blockNumber Origin block number the log was emitted in.
    /// @param opCode How many topics the original log had (LOG0..LOG4).
    /// @param blockHash Origin block hash, as uint256.
    /// @param txHash Origin transaction hash, as uint256.
    /// @param logIndex Index of the log within its origin block.
    struct LogRecord {
        uint256 chainId;
        address contractAddress;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
        bytes data;
        uint256 blockNumber;
        uint256 opCode;
        uint256 blockHash;
        uint256 txHash;
        uint256 logIndex;
    }

    /// @notice Called by the system contract whenever a subscribed log appears.
    /// @param log_ The normalized log record.
    function react(LogRecord memory log_) external;
}
