// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IdentityRegistryExtraCheckHarness} from "src/mocks/harness/IdentityRegistryDelegationHarness.sol";
import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";

/**
 * @title RuleIdentityRegistryDelegation
 * @notice The `transferFrom` path must always consult the direct restriction check, whether or not a
 *         registry is configured and whether or not the transfer is a burn (Nethermind AuditAgent
 *         NM-3; the mirror of `CLAUDE_ANALYSIS.md` F-2 on {RuleSanctionsListBase}).
 * @dev The subclass under test adds a registry-independent check. Before the fix,
 *      `_detectTransferRestrictionFrom` returned `TRANSFER_OK` outright when the registry was unset
 *      or `to == address(0)`, so the subclass's check applied to `transfer` but not to
 *      `transferFrom`. `testExtraCheckAppliesToTransferFromWithNoRegistry` and
 *      `testExtraCheckAppliesToBurnFrom` fail against that implementation and are the reason the
 *      restructure exists.
 */
contract RuleIdentityRegistryDelegation is Test, HelperContract {
    address private constant BLOCKED = address(0xB10C);
    address private constant UNVERIFIED = address(98);

    IdentityRegistryMock private registry;

    function setUp() public {
        registry = new IdentityRegistryMock();
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        registry.setVerified(ADDRESS3, true);
        registry.setVerified(BLOCKED, true);
    }

    function _withoutRegistry() internal returns (IdentityRegistryExtraCheckHarness) {
        return new IdentityRegistryExtraCheckHarness(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false, BLOCKED);
    }

    function _withRegistry(bool checkSpender_) internal returns (IdentityRegistryExtraCheckHarness) {
        return
            new IdentityRegistryExtraCheckHarness(
                DEFAULT_ADMIN_ADDRESS, address(registry), false, checkSpender_, BLOCKED
            );
    }

    /*//////////////////////////////////////////////////////////////
                        No registry configured
    //////////////////////////////////////////////////////////////*/

    function testExtraCheckAppliesToTransferWithNoRegistry() public {
        // This direction always worked: the direct path calls the hook unconditionally.
        IdentityRegistryExtraCheckHarness rule = _withoutRegistry();
        assertEq(rule.detectTransferRestriction(BLOCKED, ADDRESS2, 10), rule.CODE_EXTRA_BLOCKED());
    }

    function testExtraCheckAppliesToTransferFromWithNoRegistry() public {
        // THE REGRESSION: with the early return in place this returned TRANSFER_OK, so `transfer`
        // and `transferFrom` disagreed about the same pair of addresses.
        IdentityRegistryExtraCheckHarness rule = _withoutRegistry();
        assertEq(
            rule.detectTransferRestrictionFrom(ADDRESS3, BLOCKED, ADDRESS2, 10),
            rule.CODE_EXTRA_BLOCKED(),
            "transferFrom must reach the same hook as transfer"
        );
        assertFalse(rule.canTransferFrom(ADDRESS3, BLOCKED, ADDRESS2, 10));
    }

    function testTheTwoEntrypointsAgreeWithNoRegistry() public {
        IdentityRegistryExtraCheckHarness rule = _withoutRegistry();
        assertEq(
            rule.detectTransferRestriction(ADDRESS1, BLOCKED, 10),
            rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, BLOCKED, 10),
            "the receiver leg must be screened identically on both paths"
        );
        // An unrelated pair is still unrestricted; the rule is not simply rejecting everything.
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        Burn (to == address(0))
    //////////////////////////////////////////////////////////////*/

    function testExtraCheckAppliesToBurnFrom() public {
        // THE SECOND REGRESSION: the burn early return skipped the delegation too, so a subclass
        // check on a burning `from` applied to `burn` but not to `burnFrom`.
        IdentityRegistryExtraCheckHarness rule = _withRegistry(false);
        assertEq(rule.detectTransferRestriction(BLOCKED, ZERO_ADDRESS, 10), rule.CODE_EXTRA_BLOCKED());
        assertEq(
            rule.detectTransferRestrictionFrom(ADDRESS3, BLOCKED, ZERO_ADDRESS, 10),
            rule.CODE_EXTRA_BLOCKED(),
            "burnFrom must reach the same hook as burn"
        );
    }

    function testBurnStaysExemptFromTheSpenderCheck() public {
        // Delegating the burn must NOT expose it to the opt-in spender check: ERC-3643 states that
        // burn bypasses all eligibility checks.
        IdentityRegistryExtraCheckHarness rule = _withRegistry(true);
        assertEq(rule.detectTransferRestrictionFrom(UNVERIFIED, ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        Registry configured
    //////////////////////////////////////////////////////////////*/

    function testExtraCheckStillAppliesWithARegistry() public {
        IdentityRegistryExtraCheckHarness rule = _withRegistry(false);
        assertEq(rule.detectTransferRestriction(BLOCKED, ADDRESS2, 10), rule.CODE_EXTRA_BLOCKED());
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, BLOCKED, ADDRESS2, 10), rule.CODE_EXTRA_BLOCKED());
    }

    function testTheSpenderCheckStillTakesPriority() public {
        // The registry-driven spender check must still short-circuit ahead of the delegated hook.
        IdentityRegistryExtraCheckHarness rule = _withRegistry(true);
        assertEq(
            rule.detectTransferRestrictionFrom(UNVERIFIED, BLOCKED, ADDRESS2, 10), CODE_ADDRESS_SPENDER_NOT_VERIFIED
        );
    }

    function testBaseScreeningIsUnchanged() public {
        IdentityRegistryExtraCheckHarness rule = _withRegistry(false);
        // ERC-3643: only the receiver must be verified.
        assertEq(rule.detectTransferRestriction(ADDRESS1, UNVERIFIED, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
        assertEq(rule.detectTransferRestriction(UNVERIFIED, ADDRESS2, 10), TRANSFER_OK);
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        // Mint is screened on the receiver only; an unverified minter is not blocked.
        assertEq(rule.detectTransferRestrictionFrom(UNVERIFIED, ZERO_ADDRESS, ADDRESS2, 10), TRANSFER_OK);
    }
}
