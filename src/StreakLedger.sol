// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "./reactive/IPayable.sol";
import { AbstractCallback } from "./reactive/AbstractCallback.sol";

/// @title StreakLedger — the callback contract (Base Sepolia).
/// @notice The permanent journal of the check-in automation. The Reactive
///         Network's Base Sepolia callback proxy calls `recordCheckIn` here
///         every time the StreakReactive contract on Lasna sees a check-in.
///         The ledger counts executions, remembers the latest one, mirrors
///         each user's streak, and celebrates weekly milestones — all
///         without anyone sending it a transaction by hand.
/// @dev Authenticity is double-checked on every call: the caller must be
///      this chain's callback proxy (`onlyServiceProvider`, inherited), and
///      the sender address the proxy injects into the payload must be our
///      reactive contract (`onlyCallbackSender`).
contract StreakLedger is AbstractCallback {
    /// @notice One journaled check-in.
    /// @param user The user whose check-in was journaled.
    /// @param streak The user's streak as reported by the origin event.
    /// @param originTimestamp When the check-in happened on the origin chain.
    /// @param recordedAt When this callback executed.
    event CheckInRecorded(address indexed user, uint256 streak, uint256 originTimestamp, uint256 recordedAt);

    /// @notice A user's streak reached a whole number of weeks.
    event MilestoneReached(address indexed user, uint256 streak);

    /// @notice Total callbacks executed by this ledger. This counter is the
    ///         headline proof that the automation loop ran end to end.
    uint256 public executionCount;

    /// @notice Block timestamp of the most recent callback execution.
    uint256 public lastExecutionAt;

    /// @notice Origin timestamp carried by the most recent callback.
    uint256 public lastOriginTimestamp;

    /// @notice User of the most recent callback.
    address public lastUser;

    /// @notice Latest streak mirrored per user.
    mapping(address => uint256) public streakOf;

    /// @notice How many check-ins were journaled per user.
    mapping(address => uint256) public checkInsOf;

    /// @param callbackProxy_ The Base Sepolia callback proxy.
    /// @param callbackSender_ The StreakReactive contract on Lasna.
    constructor(IPayable callbackProxy_, address callbackSender_)
        payable
        AbstractCallback(callbackProxy_, callbackSender_)
    {}

    /// @notice Settles any outstanding debt to the callback proxy out of
    ///         this contract's own balance.
    function coverDebt() external {
        _coverDebt();
    }

    /// @notice Journals one check-in. Called by the callback proxy on behalf
    ///         of the reactive contract.
    /// @param reactive_ Injected by the network: the reactive contract that
    ///        requested this callback. Always the first argument.
    /// @param user_ The user who checked in.
    /// @param streak_ The user's streak after that check-in.
    /// @param originTimestamp_ When the check-in happened on the origin chain.
    function recordCheckIn(address reactive_, address user_, uint256 streak_, uint256 originTimestamp_)
        external
        onlyServiceProvider
        onlyCallbackSender(reactive_)
    {
        executionCount += 1;
        lastExecutionAt = block.timestamp;
        lastOriginTimestamp = originTimestamp_;
        lastUser = user_;
        streakOf[user_] = streak_;
        checkInsOf[user_] += 1;

        emit CheckInRecorded(user_, streak_, originTimestamp_, block.timestamp);

        if (streak_ > 0 && streak_ % 7 == 0) {
            emit MilestoneReached(user_, streak_);
        }
    }
}
