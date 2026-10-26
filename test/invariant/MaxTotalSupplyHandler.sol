// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {
    RuleMaxTotalSupplyInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxTotalSupplyInvariantStorage.sol";

/**
 * @title MaxTotalSupplyHandler
 * @notice Invariant-test handler driving a real CMTAT token guarded by {RuleMaxTotalSupply}.
 * @dev The rule keeps no state of its own: its "state" is the token's supply. So the handler drives the
 * token through every operation that changes the supply (mint, burn, `burnAndMint`, forced burn), plus
 * transfers and cap changes, and records, for each mint, whether the rule's decision was the right one:
 *   - a mint that went through must have fitted (`supplyBefore + value <= cap`), else `ghostBreaches++`;
 *   - a mint that fitted must have gone through, else `ghostFalseRejections++`;
 *   - a mint may only fail with the rule's own error, else `ghostUnexpectedReverts++`.
 * Mints are attempted with `try`, since rejection is an expected outcome; every other action is bounded
 * so it cannot revert (`fail_on_revert = true`).
 */
contract MaxTotalSupplyHandler is Test {
    address internal constant ADMIN = address(1);

    CMTATStandardStandalone public immutable token;
    RuleMaxTotalSupply public immutable rule;

    uint256 public ghostBreaches;
    uint256 public ghostFalseRejections;
    uint256 public ghostUnexpectedReverts;
    uint256 public mintsAccepted;
    uint256 public mintsRejected;

    /// @dev Small actor set so balances accumulate and burns have something to burn.
    address[3] internal _actors = [address(0xC1), address(0xC2), address(0xC3)];

    /// @dev Values stay around the cap so the fuzzer keeps crossing it in both directions.
    uint256 internal constant MAX_AMOUNT = 1000;

    constructor(CMTATStandardStandalone token_, RuleMaxTotalSupply rule_) {
        token = token_;
        rule = rule_;
    }

    /*//////////////////////////////////////////////////////////////
                            HANDLER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(uint256 actorSeed, uint256 value) external {
        value = bound(value, 0, MAX_AMOUNT);
        uint256 supplyBefore = token.totalSupply();
        uint256 cap = rule.maxTotalSupply();
        vm.prank(ADMIN);
        try token.mint(_actor(actorSeed), value) {
            _recordAccepted(supplyBefore, value, cap);
        } catch (bytes memory reason) {
            _recordRejected(supplyBefore, value, cap, reason);
        }
    }

    /// @dev Probes the boundary: mints the remaining room minus one, exactly, or plus one. Random amounts
    /// almost never land on `headroom + 1`, the one value an off-by-one in the cap check would let through.
    function mintAtBoundary(uint256 actorSeed, uint256 offsetSeed) external {
        uint256 supplyBefore = token.totalSupply();
        uint256 cap = rule.maxTotalSupply();
        uint256 headroom = supplyBefore >= cap ? 0 : cap - supplyBefore;
        uint256 offset = offsetSeed % 3; // 0: -1, 1: exact, 2: +1
        if (offset == 0 && headroom == 0) offset = 1;
        uint256 value = headroom + offset - 1;
        vm.prank(ADMIN);
        try token.mint(_actor(actorSeed), value) {
            _recordAccepted(supplyBefore, value, cap);
        } catch (bytes memory reason) {
            _recordRejected(supplyBefore, value, cap, reason);
        }
    }

    /// @dev The burn leg runs first, so the mint leg is judged against the supply after the burn.
    function burnAndMint(uint256 fromSeed, uint256 toSeed, uint256 burnValue, uint256 mintValue) external {
        address from = _actor(fromSeed);
        burnValue = bound(burnValue, 0, token.balanceOf(from));
        mintValue = bound(mintValue, 0, MAX_AMOUNT);
        uint256 supplyAfterBurn = token.totalSupply() - burnValue;
        uint256 cap = rule.maxTotalSupply();
        vm.prank(ADMIN);
        try token.burnAndMint(from, _actor(toSeed), burnValue, mintValue, "") {
            _recordAccepted(supplyAfterBurn, mintValue, cap);
        } catch (bytes memory reason) {
            _recordRejected(supplyAfterBurn, mintValue, cap, reason);
        }
    }

    function burn(uint256 actorSeed, uint256 value) external {
        address from = _actor(actorSeed);
        value = bound(value, 0, token.balanceOf(from));
        vm.prank(ADMIN);
        token.burn(from, value);
    }

    /// @dev Bypasses the rule engine entirely, but still lowers the supply the rule reads.
    function forcedBurn(uint256 actorSeed, uint256 value) external {
        address from = _actor(actorSeed);
        value = bound(value, 1, MAX_AMOUNT);
        if (token.balanceOf(from) < value) return;
        vm.prank(ADMIN);
        token.forcedTransfer(from, address(0), value);
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 value) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        value = bound(value, 0, token.balanceOf(from));
        vm.prank(from);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(to, value);
    }

    /// @dev Includes caps below the current supply, the freeze lever.
    function setCap(uint256 newCap) external {
        newCap = bound(newCap, 0, 4 * MAX_AMOUNT);
        vm.prank(ADMIN);
        rule.setMaxTotalSupply(newCap);
    }

    /// @dev Relative cap changes, bounded so they can neither underflow nor revert.
    function increaseCap(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        vm.prank(ADMIN);
        rule.increaseMaxTotalSupply(amount);
    }

    function decreaseCap(uint256 amount) external {
        amount = bound(amount, 0, rule.maxTotalSupply());
        vm.prank(ADMIN);
        rule.decreaseMaxTotalSupply(amount);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _recordAccepted(uint256 supplyBefore, uint256 value, uint256 cap) internal {
        ++mintsAccepted;
        if (supplyBefore + value > cap) ++ghostBreaches;
    }

    function _recordRejected(uint256 supplyBefore, uint256 value, uint256 cap, bytes memory reason) internal {
        ++mintsRejected;
        // CMTAT >= v3.3 sends mints on the 4-argument path, hence the `...From` error.
        // Truncation is the point: the first four bytes of the revert data are the error selector.
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 selector = bytes4(reason);
        if (
            selector != RuleMaxTotalSupplyInvariantStorage.RuleMaxTotalSupply_InvalidTransfer.selector
                && selector != RuleMaxTotalSupplyInvariantStorage.RuleMaxTotalSupply_InvalidTransferFrom.selector
        ) {
            ++ghostUnexpectedReverts;
        } else if (supplyBefore + value <= cap) {
            ++ghostFalseRejections;
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return _actors[seed % _actors.length];
    }

    function actor(uint256 index) external view returns (address) {
        return _actors[index];
    }
}
