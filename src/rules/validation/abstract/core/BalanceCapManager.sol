// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleMaxBalanceInvariantStorage} from "../invariant/RuleMaxBalanceInvariantStorage.sol";
import {IBalanceOf} from "../../../interfaces/IBalanceOf.sol";
import {RuleAddressSetInternal} from "../RuleAddressSet/RuleAddressSetInternal.sol";
import {CapAccounting} from "./CapAccounting.sol";

/**
 * @title BalanceCapManager
 * @notice Per-address holding cap: the observed token, the cap, the exemption list, and how much a
 * given address may still receive.
 *
 * @dev Declares **no constructor**, so an upgradeable variant can set the same state from an
 * initializer. {_capExceeded} and {_remainingCapacity} answer in booleans and token units, leaving
 * the restriction codes to the rule.
 *
 * @dev `maxBalance = 0` forbids holding entirely; it does not disable the cap.
 *
 * @dev {_balanceOf} must never revert, because the rule calls it from MUST-NOT-revert views, so it is
 * `try/catch`-wrapped. That is only safe because the setter requires the token to have code and
 * EIP-6780 makes it permanent: a `try` to a codeless address reverts *uncatchably*. Assumes a
 * Cancun-or-later chain.
 *
 * @dev The exemption list reuses {RuleAddressSetInternal}, so the set storage, the zero-address guard
 * and the batch semantics are shared code rather than a second implementation.
 */
abstract contract BalanceCapManager is CapAccounting, RuleAddressSetInternal, RuleMaxBalanceInvariantStorage {
    /**
     * @notice The token whose balances are observed.
     * @dev Trusted to report an accurate balance; not trusted to stay callable.
     */
    IBalanceOf public balanceToken;
    /**
     * @notice Maximum number of tokens a single non-exempt address may hold.
     */
    uint256 public maxBalance;

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMaxBalanceManager() {
        _authorizeMaxBalanceManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the maximum balance allowed per non-exempt address.
     * @dev Lowering the cap does **not** claw back balances that already exceed it. Existing holders
     * keep their tokens and may still send them away; they simply cannot receive more until they are
     * back under the cap.
     * @param newMaxBalance The new cap. `0` forbids holding entirely; it does not disable the cap.
     */
    function setMaxBalance(uint256 newMaxBalance) public virtual onlyMaxBalanceManager {
        _setMaxBalance(newMaxBalance);
    }

    /**
     * @notice Updates the token whose balances are observed.
     * @param newBalanceToken The new token contract; must be a contract exposing `balanceOf`.
     */
    function setBalanceToken(address newBalanceToken) public virtual onlyMaxBalanceManager {
        _setBalanceToken(newBalanceToken);
    }

    /**
     * @notice Exempts an address from the cap.
     * @dev Reverts if the address is already exempt, matching the single-item convention used
     * elsewhere in the library. `address(0)` is rejected: it is the mint/burn sentinel, never a
     * holder.
     * @param targetAddress The address to exempt.
     */
    function addExemptAddress(address targetAddress) public virtual onlyMaxBalanceManager {
        _addExemptAddress(targetAddress);
    }

    /**
     * @notice Removes an address's exemption.
     * @dev Reverts if the address is not exempt. The address keeps whatever it already holds; it
     * simply cannot receive more once over the cap.
     * @param targetAddress The address to bring back under the cap.
     */
    function removeExemptAddress(address targetAddress) public virtual onlyMaxBalanceManager {
        _removeExemptAddress(targetAddress);
    }

    /**
     * @notice Exempts several addresses in one call.
     * @dev Duplicates are skipped and counted rather than reverting; `address(0)` rejects the whole
     * batch. Both follow the library-wide batch convention.
     * @param targetAddresses The addresses to exempt.
     */
    function addExemptAddresses(address[] calldata targetAddresses) public virtual onlyMaxBalanceManager {
        (uint256 added, uint256 skipped) = _addAddresses(targetAddresses);
        emit ExemptAddressesAdded(targetAddresses, added, skipped);
    }

    /**
     * @notice Removes the exemption from several addresses in one call.
     * @dev Addresses that are not exempt are skipped and counted rather than reverting.
     * @param targetAddresses The addresses to bring back under the cap.
     */
    function removeExemptAddresses(address[] calldata targetAddresses) public virtual onlyMaxBalanceManager {
        (uint256 removed, uint256 skipped) = _removeAddresses(targetAddresses);
        emit ExemptAddressesRemoved(targetAddresses, removed, skipped);
    }

    /**
     * @notice Returns whether an address is exempt from the cap.
     * @param targetAddress The address to test.
     * @return True when the address may hold any amount.
     */
    function isExemptAddress(address targetAddress) public view virtual returns (bool) {
        return _isAddressListed(targetAddress);
    }

    /**
     * @notice Returns how many addresses are exempt.
     * @return The number of exempt addresses.
     */
    function exemptAddressCount() public view virtual returns (uint256) {
        return _listedAddressCount();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exempts an address: guards, writes and announces, in one place.
     * @dev Owns the guards as well as the event, so every write path gets both. A subclass that
     *      wanted to pre-exempt a treasury address from its constructor can call this instead of
     *      restating the two `require`s, which is what the scalar setters already do via
     *      {_setMaxBalance} and {_setBalanceToken}.
     *
     *      `_addAddress` does not guard the sentinel; the caller must, exactly as the whitelist
     *      rules and `IdentityRegistryWhitelist` do. The batch path is guarded separately, by the
     *      function pointer `_addAddresses` passes to `AddressSetBatchLib`. Invariant I-12.
     * @param targetAddress The address to exempt.
     */
    function _addExemptAddress(address targetAddress) internal virtual {
        require(targetAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
        require(_addAddress(targetAddress), RuleAddressSet_AddressAlreadyListed());
        emit ExemptAddressAdded(targetAddress);
    }

    /**
     * @notice Removes an exemption: guards, writes and announces, in one place.
     * @param targetAddress The address to bring back under the cap.
     */
    function _removeExemptAddress(address targetAddress) internal virtual {
        require(_removeAddress(targetAddress), RuleAddressSet_AddressNotFound());
        emit ExemptAddressRemoved(targetAddress);
    }

    /**
     * @notice Stores the cap and emits {MaxBalanceUpdated}.
     * @param newMaxBalance The new cap.
     */
    function _setMaxBalance(uint256 newMaxBalance) internal virtual {
        maxBalance = newMaxBalance;
        emit MaxBalanceUpdated(newMaxBalance);
    }

    /**
     * @notice Stores the observed token and emits {MaxBalanceTokenUpdated}.
     * @dev Probes `balanceOf` at configuration time so a token that cannot serve the check fails
     * loudly at setup instead of silently blocking every transfer.
     * @param newBalanceToken The new token contract.
     */
    function _setBalanceToken(address newBalanceToken) internal virtual {
        require(newBalanceToken != address(0), RuleMaxBalance_TokenAddressZeroNotAllowed());
        // Explicit, rather than relying on the uncatchable extcodesize revert the probe below happens
        // to produce for a codeless address: that is compiler behaviour, not a check.
        require(newBalanceToken.code.length != 0, RuleMaxBalance_TokenIsNotAContract(newBalanceToken));
        try IBalanceOf(newBalanceToken).balanceOf(address(this)) returns (uint256) {
        // callable
        }
        catch {
            revert RuleMaxBalance_TokenBalanceUnavailable(newBalanceToken);
        }
        balanceToken = IBalanceOf(newBalanceToken);
        emit MaxBalanceTokenUpdated(newBalanceToken);
    }

    /**
     * @notice Authorization hook invoked before any configuration or exemption change.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeMaxBalanceManager() internal view virtual;

    /**
     * @notice Returns the balance `to` may still receive before reaching the cap.
     * @dev Never reverts. Kept `internal` and code-free deliberately: the rule wraps it in a public
     * `remainingCapacity` that reports an ERC-1404 restriction code, which is a concern this
     * contract does not carry.
     * @param to The prospective receiver.
     * @return balanceAvailable False when the balance could not be read; `headroom` is then
     * meaningless and the caller should treat the query as failed.
     * @return headroom Remaining capacity in token units. `type(uint256).max` for an exempt address
     * or the burn sentinel.
     */
    function _remainingCapacity(address to) internal view virtual returns (bool balanceAvailable, uint256 headroom) {
        if (to == address(0) || _isAddressListed(to)) {
            return (true, type(uint256).max);
        }
        (bool available, uint256 balance) = _balanceOf(to);
        if (!available) {
            return (false, 0);
        }
        return (true, _capHeadroom(balance, maxBalance));
    }

    /**
     * @notice Reads an address's balance without ever reverting.
     * @dev Wrapped in `try/catch` so the rule's read path stays revert-free if the token breaks after
     * configuration -- a proxy upgraded to something that reverts, or a pausable implementation that
     * reverts while paused.
     * @param account The address to query.
     * @return available True when the balance could be read.
     * @return balance The balance; meaningless when `available` is false.
     */
    function _balanceOf(address account) internal view virtual returns (bool available, uint256 balance) {
        try balanceToken.balanceOf(account) returns (uint256 balance_) {
            return (true, balance_);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @notice Reports whether `to` receiving `value` would breach its cap, without ever reverting.
     * @dev Answers in booleans rather than restriction codes, so the caller owns the ERC-1404
     * mapping. Burns and exempt receivers are resolved before any balance is read, so they keep
     * working while the token is unreadable. Overflow-safe: `balance + value` could exceed uint256 on
     * a MUST-NOT-revert path, so the comparison uses the remaining headroom instead.
     * @param to The receiver whose resulting balance is checked.
     * @param value The amount that would be received.
     * @return balanceAvailable False when the balance could not be read; `exceeded` is then
     * meaningless and the caller should treat the check as failed.
     * @return exceeded True when the transfer would push `to` past {maxBalance}.
     */
    function _capExceeded(address to, uint256 value)
        internal
        view
        virtual
        returns (bool balanceAvailable, bool exceeded)
    {
        // Burns cannot breach a maximum, and address(0) is the sentinel rather than a holder.
        // Exempt receivers may hold any amount. Neither reads a balance.
        if (to == address(0) || _isAddressListed(to)) {
            return (true, false);
        }
        uint256 balance;
        (balanceAvailable, balance) = _balanceOf(to);
        if (!balanceAvailable) {
            return (false, false);
        }
        return (true, _capExceededBy(balance, maxBalance, value));
    }
}
