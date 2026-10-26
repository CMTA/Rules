// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleEngine2771} from "RuleEngine/deployment/accessControl/RuleEngine2771.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {
    RuleBlacklistInvariantStorage
} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleBlacklistInvariantStorage.sol";
import {
    RuleSanctionsListInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleSanctionsListInvariantStorage.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {DeployCMTATWithBlacklistAndSanctionsList} from "script/DeployCMTATWithBlacklistAndSanctionsList.s.sol";

/**
 * @title DeployCMTATWithBlacklistAndSanctionsListTest
 * @notice Tests for the DeployCMTATWithBlacklistAndSanctionsList deployment script.
 *
 * Covers:
 *   - Deployment correctness (wiring, admin ownership)
 *   - Transfer allowed when no restriction applies
 *   - Transfer blocked when sender or recipient is blacklisted
 *   - Transfer blocked when sender or recipient is sanctioned
 *   - detectTransferRestriction returns the correct code for each rule
 */
contract DeployCMTATWithBlacklistAndSanctionsListTest is
    Test,
    RuleBlacklistInvariantStorage,
    RuleSanctionsListInvariantStorage
{
    address constant ADMIN = address(1);
    address constant FORWARDER = address(0xF0);
    address constant ADDRESS1 = address(5);
    address constant ADDRESS2 = address(6);
    address constant ADDRESS3 = address(7);
    uint8 constant TRANSFER_OK = 0;
    uint256 constant INITIAL_BALANCE = 100;

    CMTATStandardStandalone token;
    RuleEngine ruleEngine;
    RuleBlacklist ruleBlacklist;
    RuleSanctionsList ruleSanctionsList;
    SanctionListOracle sanctionOracle;

    function setUp() public {
        sanctionOracle = new SanctionListOracle();

        DeployCMTATWithBlacklistAndSanctionsList script = new DeployCMTATWithBlacklistAndSanctionsList();
        // The script contract is the acting deployer here: a direct deploy() call is not a broadcast,
        // so it makes the wiring calls itself.
        (token, ruleEngine, ruleBlacklist, ruleSanctionsList) =
            script.deploy(ADMIN, address(script), address(0), ISanctionsList(address(sanctionOracle)));

        // Mint initial balances before any restrictions are applied.
        vm.prank(ADMIN);
        token.mint(ADDRESS1, INITIAL_BALANCE);
        vm.prank(ADMIN);
        token.mint(ADDRESS2, INITIAL_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                          DEPLOYMENT CHECKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice ERC-2771 is opt-in since RuleEngine v3.0.0-rc7: without a forwarder the script deploys the
     *         plain `RuleEngine`, which has no forwarder surface at all.
     */
    function testRuleEngineHasNoForwarderWhenNoneIsGiven() public view {
        (bool ok,) = address(ruleEngine).staticcall(abi.encodeWithSignature("isTrustedForwarder(address)", FORWARDER));
        assertFalse(ok);
    }

    /**
     * @notice With a forwarder the script deploys `RuleEngine2771`, so the engine trusts the same forwarder
     *         as the token and the rules.
     */
    function testRuleEngineTrustsTheForwarderWhenOneIsGiven() public {
        DeployCMTATWithBlacklistAndSanctionsList script = new DeployCMTATWithBlacklistAndSanctionsList();
        (CMTATStandardStandalone t, RuleEngine engine,,) =
            script.deploy(ADMIN, address(script), FORWARDER, ISanctionsList(address(sanctionOracle)));
        assertTrue(RuleEngine2771(address(engine)).isTrustedForwarder(FORWARDER));
        assertEq(address(t.ruleEngine()), address(engine));
    }

    function testRuleEngineIsSetOnToken() public view {
        assertEq(address(token.ruleEngine()), address(ruleEngine));
    }

    function testAdminOwnsToken() public view {
        assertTrue(token.hasRole(bytes32(0), ADMIN));
    }

    function testAdminOwnsRuleEngine() public view {
        assertTrue(ruleEngine.hasRole(bytes32(0), ADMIN));
    }

    function testAdminOwnsBlacklistRule() public view {
        assertTrue(ruleBlacklist.hasRole(bytes32(0), ADMIN));
    }

    function testAdminOwnsSanctionsListRule() public view {
        assertTrue(ruleSanctionsList.hasRole(bytes32(0), ADMIN));
    }

    /*//////////////////////////////////////////////////////////////
                     TRANSFER — NO RESTRICTIONS
    //////////////////////////////////////////////////////////////*/

    function testTransferSucceedsWhenNoRestrictions() public {
        vm.prank(ADDRESS1);
        assertTrue(token.transfer(ADDRESS2, 10));
    }

    function testDetectTransferRestrictionNoRestriction() public view {
        uint8 code = token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(code, TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                          BLACKLIST — SENDER
    //////////////////////////////////////////////////////////////*/

    function testTransferFailsWhenSenderBlacklisted() public {
        uint256 amount = 10;
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS1);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransfer.selector,
                address(ruleBlacklist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_FROM_IS_BLACKLISTED
            )
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, amount);
    }

    function testDetectTransferRestrictionWhenSenderBlacklisted() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS1);

        uint8 code = token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(code, CODE_ADDRESS_FROM_IS_BLACKLISTED);
    }

    /*//////////////////////////////////////////////////////////////
                         BLACKLIST — RECIPIENT
    //////////////////////////////////////////////////////////////*/

    function testTransferFailsWhenRecipientBlacklisted() public {
        uint256 amount = 10;
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS2);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransfer.selector,
                address(ruleBlacklist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_TO_IS_BLACKLISTED
            )
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, amount);
    }

    function testDetectTransferRestrictionWhenRecipientBlacklisted() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS2);

        uint8 code = token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(code, CODE_ADDRESS_TO_IS_BLACKLISTED);
    }

    /*//////////////////////////////////////////////////////////////
                        SANCTIONS LIST — SENDER
    //////////////////////////////////////////////////////////////*/

    function testTransferFailsWhenSenderSanctioned() public {
        uint256 amount = 10;
        sanctionOracle.addToSanctionsList(ADDRESS1);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleSanctionsList_InvalidTransfer.selector,
                address(ruleSanctionsList),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_FROM_IS_SANCTIONED
            )
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, amount);
    }

    function testDetectTransferRestrictionWhenSenderSanctioned() public {
        sanctionOracle.addToSanctionsList(ADDRESS1);

        uint8 code = token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(code, CODE_ADDRESS_FROM_IS_SANCTIONED);
    }

    /*//////////////////////////////////////////////////////////////
                       SANCTIONS LIST — RECIPIENT
    //////////////////////////////////////////////////////////////*/

    function testTransferFailsWhenRecipientSanctioned() public {
        uint256 amount = 10;
        sanctionOracle.addToSanctionsList(ADDRESS2);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleSanctionsList_InvalidTransfer.selector,
                address(ruleSanctionsList),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_TO_IS_SANCTIONED
            )
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, amount);
    }

    function testDetectTransferRestrictionWhenRecipientSanctioned() public {
        sanctionOracle.addToSanctionsList(ADDRESS2);

        uint8 code = token.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(code, CODE_ADDRESS_TO_IS_SANCTIONED);
    }

    /*//////////////////////////////////////////////////////////////
                        RULE PRIORITY (BLACKLIST FIRST)
    //////////////////////////////////////////////////////////////*/

    /// @notice When a sender is both blacklisted and sanctioned, the blacklist rule
    ///         fires first because it was registered first in the RuleEngine.
    function testBlacklistTakesPriorityOverSanctions() public {
        uint256 amount = 10;
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS1);
        sanctionOracle.addToSanctionsList(ADDRESS1);

        uint8 code = token.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(code, CODE_ADDRESS_FROM_IS_BLACKLISTED);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT / BURN
    //////////////////////////////////////////////////////////////*/

    function testMintSucceedsWhenRecipientNotBlacklisted() public {
        vm.prank(ADMIN);
        token.mint(ADDRESS3, 50);

        assertEq(token.balanceOf(ADDRESS3), 50);
    }

    function testMintFailsWhenRecipientBlacklisted() public {
        uint256 amount = 50;
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS3);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransferFrom.selector,
                address(ruleBlacklist),
                ADMIN,
                address(0),
                ADDRESS3,
                amount,
                CODE_ADDRESS_TO_IS_BLACKLISTED
            )
        );
        vm.prank(ADMIN);
        token.mint(ADDRESS3, amount);
    }
}
