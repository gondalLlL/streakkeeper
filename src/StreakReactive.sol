// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "./reactive/ISystemContract.sol";
import { IReactive } from "./reactive/IReactive.sol";
import { AbstractReactive } from "./reactive/AbstractReactive.sol";

/// @title StreakReactive — the reactive contract (Reactive Lasna testnet).
/// @notice Subscribes to `CheckedIn` events from the CheckIn origin contract
///         on Base Sepolia. Every time a user checks in, `react()` fires on
///         Lasna and requests a callback that journals the check-in on the
///         StreakLedger back on Base Sepolia. Deploy it, fund it, point it
///         at the ledger once — then forget it: no keeper, no cron, no
///         polling. The network does the watching.
/// @dev Deployment order matters (see README): this contract is deployed
///      before the ledger, because the ledger must hard-code this contract's
///      address as its authorized callback sender, while this contract can
///      be pointed at the ledger afterwards through `setRecipient`.
contract StreakReactive is AbstractReactive {
    /// @notice A callback recipient was set (or replaced) by the owner.
    event RecipientSet(address indexed recipient);

    /// @notice One origin check-in was reacted to. Kept on Lasna as cheap,
    ///         independently checkable evidence that `react()` ran.
    event Reacted(address indexed user, uint256 streak, uint256 originTimestamp, uint256 originTxHash);

    /// @notice The caller is not the contract owner.
    error NotOwner(address sender_);

    /// @notice Chain id of the origin (and destination) chain: Base Sepolia.
    uint256 public immutable originChainId;

    /// @notice The CheckIn origin contract on Base Sepolia.
    address public immutable originContract;

    /// @notice Topic 0 of the `CheckedIn(address,uint256,uint256)` event.
    uint256 public immutable topic0;

    /// @notice Chain id callbacks are posted to (Base Sepolia).
    uint256 public immutable destinationChainId;

    /// @notice Deployer; the only account allowed to set the recipient.
    address public immutable owner;

    /// @notice The StreakLedger callback contract on Base Sepolia.
    ///         Set once after the ledger is deployed.
    address public recipient;

    /// @notice How many origin check-ins this contract has reacted to.
    uint256 public reactions;

    /// @notice Lasna timestamp of the most recent reaction.
    uint256 public lastReactionAt;

    /// @notice Gas limit handed to the callback proxy for the ledger call.
    ///         Well above the 100,000 minimum the network enforces.
    uint64 private constant CALLBACK_GAS_LIMIT = 1_000_000;

    /// @param originChainId_ Chain id of the origin contract (Base Sepolia).
    /// @param originContract_ The CheckIn contract to watch.
    /// @param topic0_ Topic 0 of the CheckedIn event.
    /// @param destinationChainId_ Chain id callbacks go to (Base Sepolia).
    constructor(uint256 originChainId_, address originContract_, uint256 topic0_, uint256 destinationChainId_)
        payable
    {
        originChainId = originChainId_;
        originContract = originContract_;
        topic0 = topic0_;
        destinationChainId = destinationChainId_;
        owner = msg.sender;

        SYSTEM.subscribe(originChainId_, originContract_, topic0_, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    /// @notice Points this contract at its ledger. Owner-only; called once
    ///         right after the ledger is deployed.
    /// @param recipient_ The StreakLedger address on Base Sepolia.
    function setRecipient(address recipient_) external {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        recipient = recipient_;
        emit RecipientSet(recipient_);
    }

    /// @notice Settles any outstanding debt to the system contract out of
    ///         this contract's own balance. Open to anyone: letting a third
    ///         party restart a funded-but-in-debt automation is a feature.
    function coverDebt() external {
        _coverDebt();
    }

    /// @inheritdoc IReactive
    function react(LogRecord memory log_) external onlySystem {
        // Only our event, only from our origin contract. Anything else falls
        // through quietly — reverting as a filter would still be billed.
        if (log_.topic0 != topic0 || log_.contractAddress != originContract) {
            return;
        }

        // CheckedIn(address indexed user, uint256 streak, uint256 timestamp):
        // the user sits in topic 1; streak and timestamp are the log data.
        address user = address(uint160(log_.topic1));
        (uint256 streak, uint256 originTimestamp) = abi.decode(log_.data, (uint256, uint256));

        reactions += 1;
        lastReactionAt = block.timestamp;
        emit Reacted(user, streak, originTimestamp, log_.txHash);

        if (recipient == address(0)) {
            return;
        }

        // The first payload argument must be an address placeholder: the
        // network overwrites it with this contract's address, which is how
        // the ledger authenticates the callback.
        bytes memory payload = abi.encodeWithSignature(
            "recordCheckIn(address,address,uint256,uint256)", address(0), user, streak, originTimestamp
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId,
                recipient: recipient,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }
}
