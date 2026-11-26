// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title CheckIn — the origin contract (Base Sepolia).
/// @notice A tiny daily check-in habit tracker. A user calls `checkIn()` —
///         at most once per UTC day — and the contract keeps their streak.
///         Every successful check-in emits `CheckedIn`, which is the event
///         the reactive contract on Lasna listens to. After deployment this
///         contract needs no owner, no keeper and no maintenance: users
///         "set it" by checking in, and the rest of the pipeline (journaling
///         the streak on the ledger) happens by itself.
contract CheckIn {
    /// @notice Emitted on every successful check-in. The user is indexed so
    ///         subscribers can filter per user; streak and day travel in
    ///         the log data.
    /// @param user The account that checked in.
    /// @param streak The user's streak after this check-in (consecutive UTC days).
    /// @param timestamp Block timestamp of the check-in.
    event CheckedIn(address indexed user, uint256 streak, uint256 timestamp);

    /// @notice The caller already checked in today (UTC).
    error AlreadyCheckedInToday(address user, uint256 day);

    /// @notice Current streak per user.
    mapping(address => uint256) public streakOf;

    /// @notice Best streak ever reached per user.
    mapping(address => uint256) public bestStreakOf;

    /// @notice UTC day number of the user's last check-in (timestamp / 86400).
    mapping(address => uint256) public lastCheckInDay;

    /// @notice Whether the user has ever checked in.
    mapping(address => bool) public hasCheckedIn;

    /// @notice Total check-ins recorded by this contract.
    uint256 public totalCheckIns;

    /// @notice Checks the caller in for today.
    /// @dev A check-in on the day right after the previous one extends the
    ///      streak; anything later restarts it at 1. Uses timestamps, not
    ///      block numbers, per the Base Sepolia guidance (200 ms blocks).
    function checkIn() external {
        uint256 today = block.timestamp / 1 days;

        if (hasCheckedIn[msg.sender] && lastCheckInDay[msg.sender] == today) {
            revert AlreadyCheckedInToday(msg.sender, today);
        }

        uint256 streak;
        if (hasCheckedIn[msg.sender] && lastCheckInDay[msg.sender] == today - 1) {
            streak = streakOf[msg.sender] + 1;
        } else {
            streak = 1;
        }

        streakOf[msg.sender] = streak;
        if (streak > bestStreakOf[msg.sender]) {
            bestStreakOf[msg.sender] = streak;
        }
        lastCheckInDay[msg.sender] = today;
        hasCheckedIn[msg.sender] = true;
        totalCheckIns += 1;

        emit CheckedIn(msg.sender, streak, block.timestamp);
    }
}
