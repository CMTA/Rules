// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuleAddressSetInternal} from "src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol";

/**
 * @notice A-1/E-1: the batch zero-address guard is passed to `AddressSetBatchLib` as an **internal function
 *         pointer**, and must stay overridable.
 * @dev Two things this pins, neither of which a compile-only check would catch:
 *
 *      1. `_requireNotZeroAddress` is `virtual`. Removing the keyword breaks this file's compilation, because
 *         the harness below declares `override`.
 *      2. Virtual dispatch actually reaches the override **through the function pointer**. Solidity resolves an
 *         internal function pointer at the point of assignment, so it is not obvious that an override installed
 *         by a derived contract is the one `addBatch` ends up calling. It is — asserted here rather than
 *         assumed, because a silently shadowed override would leave the guard looking extensible while the base
 *         implementation kept running.
 */
contract BatchGuardPointerHarness is RuleAddressSetInternal {
    error OverrideWasReached();

    function _requireNotZeroAddress(address) internal pure override {
        revert OverrideWasReached();
    }

    function addAddressesPublic(address[] calldata targets) external returns (uint256 added, uint256 skipped) {
        return _addAddresses(targets);
    }
}

contract BatchGuardPointerVirtual is Test {
    function testOverrideIsReachedThroughTheFunctionPointer() public {
        BatchGuardPointerHarness harness = new BatchGuardPointerHarness();
        address[] memory targets = new address[](1);
        targets[0] = address(0x1234);

        vm.expectRevert(BatchGuardPointerHarness.OverrideWasReached.selector);
        harness.addAddressesPublic(targets);
    }
}
