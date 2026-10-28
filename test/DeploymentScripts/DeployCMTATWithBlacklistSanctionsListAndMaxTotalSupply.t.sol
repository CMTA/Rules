// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleEngine2771} from "RuleEngine/deployment/accessControl/RuleEngine2771.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {
    RuleBlacklistInvariantStorage
} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleBlacklistInvariantStorage.sol";
import {
    RuleMaxTotalSupplyInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxTotalSupplyInvariantStorage.sol";
import {
    RuleSanctionsListInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleSanctionsListInvariantStorage.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {
    DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply
} from "script/DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply.s.sol";

/**
 * @title DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupplyTest
 * @notice Verifies the three-rule deployment script end to end: wiring, ownership hand-over, each
 *         rule enforcing on its own, and the three of them composed.
 * @dev The composition is the part a single-rule test cannot cover. Three rules in one engine raise
 *      questions none of them raises alone: which restriction code a rejected transfer reports when
 *      more than one rule objects, whether an address rule can block a mint that the supply cap would
 *      have allowed, and whether the supply cap leaves ordinary transfers alone.
 */
contract DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupplyTest is
    Test,
    RuleBlacklistInvariantStorage,
    RuleSanctionsListInvariantStorage,
    RuleMaxTotalSupplyInvariantStorage
{
    address private constant ADMIN = address(1);
    address private constant FORWARDER = address(0xF0);
    address private constant ADDRESS1 = address(5);
    address private constant ADDRESS2 = address(6);
    address private constant ADDRESS3 = address(7);
    address private constant ATTACKER = address(8);

    uint8 private constant TRANSFER_OK = 0;
    uint256 private constant MAX_SUPPLY = 1000;
    uint256 private constant INITIAL_BALANCE = 100;

    CMTATStandardStandalone private token;
    RuleEngine private ruleEngine;
    RuleBlacklist private ruleBlacklist;
    RuleSanctionsList private ruleSanctionsList;
    RuleMaxTotalSupply private ruleMaxTotalSupply;
    SanctionListOracle private oracle;

    function setUp() public {
        oracle = new SanctionListOracle();

        DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply script =
            new DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply();
        (token, ruleEngine, ruleBlacklist, ruleSanctionsList, ruleMaxTotalSupply) =
            script.deploy(ADMIN, address(script), address(0), ISanctionsList(address(oracle)), MAX_SUPPLY);

        vm.startPrank(ADMIN);
        token.mint(ADDRESS1, INITIAL_BALANCE);
        token.mint(ADDRESS2, INITIAL_BALANCE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT / WIRING
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
        DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply script =
            new DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply();
        (CMTATStandardStandalone t, RuleEngine engine,,,) =
            script.deploy(ADMIN, address(script), FORWARDER, ISanctionsList(address(oracle)), MAX_SUPPLY);
        assertTrue(RuleEngine2771(address(engine)).isTrustedForwarder(FORWARDER));
        assertEq(address(t.ruleEngine()), address(engine));
    }

    function testRuleEngineIsSetOnTheToken() public view {
        assertEq(address(token.ruleEngine()), address(ruleEngine));
    }

    function testAllThreeRulesAreRegisteredInOrder() public view {
        assertEq(ruleEngine.rulesCount(), 3);
        assertEq(ruleEngine.rule(0), address(ruleBlacklist));
        assertEq(ruleEngine.rule(1), address(ruleSanctionsList));
        assertEq(ruleEngine.rule(2), address(ruleMaxTotalSupply));
    }

    function testAdminOwnsEverythingAndTheDeployerOwnsNothing() public view {
        assertTrue(token.hasRole(bytes32(0), ADMIN));
        assertTrue(ruleEngine.hasRole(bytes32(0), ADMIN));
        assertTrue(ruleBlacklist.hasRole(bytes32(0), ADMIN));
        assertTrue(ruleSanctionsList.hasRole(bytes32(0), ADMIN));
        assertTrue(ruleMaxTotalSupply.hasRole(bytes32(0), ADMIN));
        // The deployment key must not retain standing rights.
        assertFalse(token.hasRole(bytes32(0), address(this)));
        assertFalse(ruleEngine.hasRole(bytes32(0), address(this)));
    }

    function testSupplyRuleIsBoundToThisTokenWithTheGivenCap() public view {
        assertEq(address(ruleMaxTotalSupply.tokenContract()), address(token));
        assertEq(ruleMaxTotalSupply.maxTotalSupply(), MAX_SUPPLY);
    }

    function testSanctionsOracleIsConfigured() public view {
        assertEq(address(ruleSanctionsList.sanctionsList()), address(oracle));
    }

    /*//////////////////////////////////////////////////////////////
                    EACH RULE ENFORCES ON ITS OWN
    //////////////////////////////////////////////////////////////*/

    function testTransferSucceedsWhenNothingApplies() public {
        vm.prank(ADDRESS1);
        token.transfer(ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), INITIAL_BALANCE + 10);
    }

    function testBlacklistedSenderIsBlocked() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS1);

        assertEq(ruleEngine.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_FROM_IS_BLACKLISTED);
        vm.prank(ADDRESS1);
        vm.expectRevert();
        token.transfer(ADDRESS2, 10);
    }

    function testBlacklistedRecipientIsBlocked() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS2);

        assertEq(ruleEngine.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_TO_IS_BLACKLISTED);
        vm.prank(ADDRESS1);
        vm.expectRevert();
        token.transfer(ADDRESS2, 10);
    }

    function testSanctionedSenderIsBlocked() public {
        oracle.addToSanctionsList(ADDRESS1);

        assertEq(ruleEngine.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_FROM_IS_SANCTIONED);
        vm.prank(ADDRESS1);
        vm.expectRevert();
        token.transfer(ADDRESS2, 10);
    }

    function testSanctionedRecipientIsBlocked() public {
        oracle.addToSanctionsList(ADDRESS2);

        assertEq(ruleEngine.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_TO_IS_SANCTIONED);
        vm.prank(ADDRESS1);
        vm.expectRevert();
        token.transfer(ADDRESS2, 10);
    }

    /*//////////////////////////////////////////////////////////////
                        THE SUPPLY CAP
    //////////////////////////////////////////////////////////////*/

    function testMintUpToTheCapSucceeds() public {
        uint256 headroom = MAX_SUPPLY - token.totalSupply();
        vm.prank(ADMIN);
        token.mint(ADDRESS3, headroom);
        assertEq(token.totalSupply(), MAX_SUPPLY);
    }

    function testMintPastTheCapIsBlocked() public {
        uint256 headroom = MAX_SUPPLY - token.totalSupply();

        assertEq(
            ruleEngine.detectTransferRestrictionFrom(ADMIN, address(0), ADDRESS3, headroom + 1),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED
        );
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(ADDRESS3, headroom + 1);
        assertEq(token.totalSupply(), INITIAL_BALANCE * 2, "a rejected mint must not move supply");
    }

    function testTheCapDoesNotRestrictOrdinaryTransfers() public {
        // Fill the supply to the cap, then move tokens around: transfers do not change totalSupply.
        vm.startPrank(ADMIN);
        token.mint(ADDRESS3, MAX_SUPPLY - token.totalSupply());
        vm.stopPrank();
        assertEq(token.totalSupply(), MAX_SUPPLY);

        vm.prank(ADDRESS1);
        token.transfer(ADDRESS2, 50);
        assertEq(token.balanceOf(ADDRESS2), INITIAL_BALANCE + 50);
    }

    function testBurningFreesHeadroomForANewMint() public {
        vm.startPrank(ADMIN);
        token.mint(ADDRESS3, MAX_SUPPLY - token.totalSupply());
        vm.stopPrank();

        // At the cap, a further mint is rejected...
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(ADDRESS3, 1);

        // ...but a burn lowers totalSupply, and the same mint then succeeds.
        vm.prank(ADMIN);
        token.burn(ADDRESS1, 10);
        vm.prank(ADMIN);
        token.mint(ADDRESS3, 10);
        assertEq(token.totalSupply(), MAX_SUPPLY);
    }

    /*//////////////////////////////////////////////////////////////
        COMPOSITION — what only the three together can show
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The engine reports the FIRST non-zero code, so registration order decides which reason
     *         a transfer rejected by several rules is attributed to.
     */
    function testTheFirstRegisteredRuleWinsTheRestrictionCode() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS1);
        oracle.addToSanctionsList(ADDRESS1);

        // Both object; the blacklist is registered first, so its code is the one surfaced.
        assertEq(ruleEngine.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_FROM_IS_BLACKLISTED);
    }

    /**
     * @notice An address rule can reject a mint the supply cap would have allowed — the rules are
     *         independent gates, not alternatives.
     */
    function testAnAddressRuleBlocksAMintThatIsWithinTheCap() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS3);

        // Well within the cap, but the recipient is blacklisted.
        assertEq(
            ruleEngine.detectTransferRestrictionFrom(ADMIN, address(0), ADDRESS3, 1), CODE_ADDRESS_TO_IS_BLACKLISTED
        );
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(ADDRESS3, 1);
    }

    /**
     * @notice And the converse: a clean address is still stopped by the cap.
     */
    function testACleanAddressIsStillStoppedByTheCap() public {
        uint256 headroom = MAX_SUPPLY - token.totalSupply();
        assertFalse(ruleBlacklist.isAddressListed(ADDRESS3));
        assertFalse(oracle.isSanctioned(ADDRESS3));

        assertEq(
            ruleEngine.detectTransferRestrictionFrom(ADMIN, address(0), ADDRESS3, headroom + 1),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED
        );
    }

    /**
     * @notice Removing a restriction re-opens the path, through the engine, without redeployment.
     */
    function testLiftingARestrictionRestoresTransfers() public {
        vm.prank(ADMIN);
        ruleBlacklist.addAddress(ADDRESS1);
        vm.prank(ADDRESS1);
        vm.expectRevert();
        token.transfer(ADDRESS2, 10);

        vm.prank(ADMIN);
        ruleBlacklist.removeAddress(ADDRESS1);

        vm.prank(ADDRESS1);
        token.transfer(ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), INITIAL_BALANCE + 10);
    }

    /**
     * @notice Every rule is reachable through the engine's aggregated message lookup.
     */
    function testEachRulesMessageIsResolvableThroughTheEngine() public view {
        assertEq(
            ruleEngine.messageForTransferRestriction(CODE_ADDRESS_FROM_IS_BLACKLISTED), TEXT_ADDRESS_FROM_IS_BLACKLISTED
        );
        assertEq(
            ruleEngine.messageForTransferRestriction(CODE_ADDRESS_FROM_IS_SANCTIONED), TEXT_ADDRESS_FROM_IS_SANCTIONED
        );
        assertEq(
            ruleEngine.messageForTransferRestriction(CODE_MAX_TOTAL_SUPPLY_EXCEEDED), TEXT_MAX_TOTAL_SUPPLY_EXCEEDED
        );
    }
}
