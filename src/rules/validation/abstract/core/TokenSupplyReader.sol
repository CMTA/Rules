// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ITotalSupply} from "../../../interfaces/ITotalSupply.sol";

/**
 * @title TokenSupplyReader
 * @notice Revert-free `totalSupply()` read shared by {RuleMaxTotalSupplyBase} and
 * {RuleChainlinkPoRBase}, which both cap minting against a foreign token's supply.
 *
 * @dev Declares **no storage**: each rule keeps its own token variable and implements
 * {_supplyToken}. Holding it here would reorder every inheriting rule's slots for no benefit.
 *
 * @dev Only the `try/catch` probe is shared, not the validation. Each rule composes
 * {_probeTotalSupplyCallable} with its own `require`s so its three configuration failures keep three
 * distinct, named errors, per the one-error-namespace-per-rule convention.
 *
 * @dev **Deployment precondition.** {_currentSupply} performs no code-length check, because a `try`
 * to a codeless address reverts *uncatchably* -- the ABI decoder fails in this frame after the call
 * returns 0 bytes, out of `catch`'s reach (not `EXTCODESIZE`, which solc >= 0.8.10 skips when return
 * data is expected). Safety comes from configuration: each setter rejects a codeless candidate and
 * EIP-6780 makes that permanent. **Assumes a Cancun-or-later chain**; on an older one a validated
 * token could still become codeless and the ERC-1404 views would revert.
 */
abstract contract TokenSupplyReader {
    /**
     * @notice The token whose `totalSupply()` this rule reads.
     * @dev Implemented by each rule against its own storage, so this base stays stateless.
     * @return The configured token.
     */
    function _supplyToken() internal view virtual returns (ITotalSupply);

    /**
     * @notice Reads the configured token's current total supply without ever reverting.
     * @dev Wrapped in `try/catch` so the ERC-1404 / ERC-3643 read path stays revert-free if the token
     * breaks after configuration -- a proxy upgraded to something that reverts, or a pausable
     * implementation that reverts while paused. Configuration already probes `totalSupply()`, so
     * reaching the failure branch means the token changed behaviour since. Callers translate
     * `available == false` into their own "supply unavailable" restriction code.
     * @return available True when the supply could be read.
     * @return supply The total supply; meaningless when `available` is false.
     */
    function _currentSupply() internal view virtual returns (bool available, uint256 supply) {
        try _supplyToken().totalSupply() returns (uint256 totalSupply_) {
            return (true, totalSupply_);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @notice Returns whether `candidate` answers `totalSupply()` without reverting.
     * @dev Used at configuration time to turn what would otherwise be a silent read-path failure
     * into an immediate, named error raised by the calling rule. `totalSupply()` is mandatory for
     * both rules -- the cap check cannot work without it -- unlike `decimals()`, which only
     * `RuleChainlinkPoR` consults and treats as optional.
     *
     * WARNING: the caller MUST have already established that `candidate` has code. A `try` call to a
     * codeless address reverts uncatchably -- the ABI decoder fails in the caller's frame, outside `catch`'s
     * reach -- and this probe cannot contain it. Note code alone is not sufficient either: a contract that
     * returns 0 bytes fails the same way.
     * @param candidate The token contract to probe.
     * @return True when `totalSupply()` is callable.
     */
    function _probeTotalSupplyCallable(address candidate) internal view virtual returns (bool) {
        try ITotalSupply(candidate).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }
}
