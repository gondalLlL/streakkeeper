// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayer } from "./IPayer.sol";
import { IPayable } from "./IPayable.sol";

/// @title Base for contracts that are billed by a single service provider:
///        the Reactive system contract (for reactive contracts) or a callback
///        proxy (for callback contracts).
/// @notice The provider collects by calling `pay()`, which sends it funds out
///        of this contract's own balance. Only the provider may call `pay()`
///        and the provider-guarded entry points. Original implementation,
///        written for this project against the Reactive Omni specification.
abstract contract AbstractPayer is IPayer {
    /// @notice The caller is not this contract's service provider.
    error NotAuthorized(address sender_, address provider_);

    /// @notice The contract balance cannot cover a requested payment.
    error InsufficientFunds(uint256 required_, uint256 available_);

    /// @notice A payment transfer to the service provider failed.
    error TransferFailed();

    /// @notice The one service provider allowed to bill this contract.
    IPayable public immutable _SERVICE_PROVIDER;

    constructor(IPayable serviceProvider_) {
        _SERVICE_PROVIDER = serviceProvider_;
    }

    /// @inheritdoc IPayer
    receive() external payable virtual {}

    /// @notice Guards entry points that only the service provider may call.
    modifier onlyServiceProvider() {
        _onlyServiceProvider();
        _;
    }

    function _onlyServiceProvider() internal view {
        if (msg.sender != address(_SERVICE_PROVIDER)) {
            revert NotAuthorized(msg.sender, address(_SERVICE_PROVIDER));
        }
    }

    /// @inheritdoc IPayer
    function pay(uint256 amount_) external onlyServiceProvider {
        _pay(payable(msg.sender), amount_);
    }

    /// @notice Settles whatever this contract currently owes its provider,
    ///         drawing on the contract's own balance.
    function _coverDebt() internal {
        uint256 amount = _SERVICE_PROVIDER.debt(address(this));
        _pay(payable(address(_SERVICE_PROVIDER)), amount);
    }

    /// @notice Sends `amount_` wei to `recipient_`, reverting if the balance
    ///         is short or the transfer itself fails.
    function _pay(address payable recipient_, uint256 amount_) internal {
        if (address(this).balance < amount_) {
            revert InsufficientFunds(amount_, address(this).balance);
        }
        if (amount_ > 0) {
            (bool success,) = recipient_.call{ value: amount_ }(new bytes(0));
            if (!success) {
                revert TransferFailed();
            }
        }
    }
}
