// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";

/**
 * @title Integration test between RuleEngine and RuleIdentityRegistry
 */
contract RuleIdentityRegistryRuleEngineIntegration is Test, HelperContract {
    IdentityRegistryMock registry;

    function setUp() public {
        registry = new IdentityRegistryMock();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleIdentityRegistry = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, false);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleIdentityRegistry);
    }

    /// @notice ERC-3643 mandates verifying only the RECEIVER, so an unverified recipient is what
    ///         blocks the transfer — not the sender.
    function testDetectRestrictionWhenReceiverNotVerified() public {
        uint256 amount = 10;
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_VERIFIED);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);
    }

    /// @notice A verified receiver is sufficient: the sender need NOT be verified (ERC-3643).
    ///         This is what lets a de-listed holder exit their position.
    function testUnverifiedSenderCanStillExitToAVerifiedReceiver() public {
        uint256 amount = 10;
        registry.setVerified(ADDRESS2, true); // receiver only

        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        assertTrue(ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount));
    }

    function testDetectRestrictionWhenVerified() public {
        uint256 amount = 10;
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);

        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }

    /// @notice ERC-3643: "`transferFrom` works the same way" — the SPENDER need not be verified.
    function testDetectRestrictionFromWithUnverifiedSpenderIsAllowed() public {
        uint256 amount = 10;
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        // ADDRESS3 (spender) is NOT verified.

        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        assertTrue(ruleEngineMock.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount));
    }

    /// @notice The stricter spender check remains available as an explicit opt-in.
    function testSpenderCheckCanBeOptedIn() public {
        uint256 amount = 10;
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleIdentityRegistry.setCheckSpender(true);

        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_VERIFIED);

        registry.setVerified(ADDRESS3, true);
        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testClearIdentityRegistryDisablesChecks() public {
        uint256 amount = 10;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleIdentityRegistry.clearIdentityRegistry();

        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = ruleEngineMock.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }

    function testBurnBypassesVerification() public {
        uint256 amount = 10;
        resUint8 = ruleEngineMock.detectTransferRestriction(ADDRESS1, address(0), amount);
        assertEq(resUint8, TRANSFER_OK);

        resUint8 = ruleEngineMock.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, address(0), amount);
        assertEq(resUint8, TRANSFER_OK);
    }
}
