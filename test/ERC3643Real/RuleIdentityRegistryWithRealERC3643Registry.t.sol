// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IIdentity} from "test/utils/onchainid/interface/IIdentity.sol";
import {IClaimIssuer} from "test/utils/onchainid/interface/IClaimIssuer.sol";
import {ClaimTopicsRegistry} from "ERC3643/registry/implementation/ClaimTopicsRegistry.sol";
import {IdentityRegistry} from "ERC3643/registry/implementation/IdentityRegistry.sol";
import {IdentityRegistryStorage} from "ERC3643/registry/implementation/IdentityRegistryStorage.sol";
import {TrustedIssuersRegistry} from "ERC3643/registry/implementation/TrustedIssuersRegistry.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {ClaimIssuerMock, OnchainIdClaimMock} from "./utils/OnchainIdClaimMocks.sol";

/**
 * @title RuleIdentityRegistryWithRealERC3643Registry
 * @notice `RuleIdentityRegistry` consulting the **genuine ERC-3643 `IdentityRegistry`** — the
 *         reference implementation vendored in `lib/ERC-3643`, with its real
 *         `IdentityRegistryStorage`, `ClaimTopicsRegistry` and `TrustedIssuersRegistry` behind it.
 *
 *         `RuleEngine -> RuleIdentityRegistry -> ERC-3643 IdentityRegistry -> claims`
 *
 * @dev The companion suite `CMTATRuleIdentityRegistryComposition` runs the same rule against *this
 *      project's* `IdentityRegistryWhitelist`. This one answers the other half of the question: does
 *      the rule work against the registry the standard actually ships? Nothing else in the repo
 *      builds the reference `IdentityRegistry` — the existing `ERC3643Real` suites plug
 *      `IdentityRegistryWhitelist` into `Token.sol`'s identity slot precisely to avoid ONCHAINID.
 *
 *      Two claim regimes are covered, because `isVerified` takes a different path through each:
 *      - **no claim topics required** — the registry short-circuits to "verified if an identity is
 *        registered", never touching ONCHAINID;
 *      - **one required topic** — the registry iterates topics, resolves trusted issuers, reads the
 *        claim off the investor's identity and asks the issuer to validate it.
 *
 *      LIMITATION: the ONCHAINID doubles in `utils/OnchainIdClaimMocks.sol` implement only
 *      `getClaim` and `isClaimValid`. Signature verification, key management and revocation are NOT
 *      exercised — the *registry's* logic runs for real, ONCHAINID's does not. Extending the two
 *      stub interfaces under `test/utils/onchainid/` was required to make the reference registry
 *      compile at all; before this suite they declared only `keyHasPurpose`.
 *
 *      This file lives in `test/ERC3643Real/` and therefore builds ONLY under
 *      `FOUNDRY_PROFILE=erc3643` (solc 0.8.30), like everything else that touches vendored ERC-3643.
 */
contract RuleIdentityRegistryWithRealERC3643Registry is Test {
    uint256 private constant CLAIM_TOPIC_KYC = 7;
    uint16 private constant COUNTRY_CH = 756;

    address private constant ADMIN = address(1);
    address private constant AGENT = address(2);
    address private constant ALICE = address(11);
    address private constant BOB = address(12);
    address private constant CAROL = address(13);
    address private constant SPENDER = address(14);

    uint8 private constant TRANSFER_OK = 0;
    uint8 private constant CODE_ADDRESS_TO_NOT_VERIFIED = 56;

    IdentityRegistry private registry;
    ClaimTopicsRegistry private claimTopics;
    TrustedIssuersRegistry private trustedIssuers;
    IdentityRegistryStorage private identityStorage;

    ClaimIssuerMock private issuer;
    RuleIdentityRegistry private rule;
    RuleEngine private ruleEngine;

    mapping(address wallet => OnchainIdClaimMock) private identityOf;

    function setUp() public {
        vm.startPrank(ADMIN);
        claimTopics = new ClaimTopicsRegistry();
        claimTopics.init();

        trustedIssuers = new TrustedIssuersRegistry();
        trustedIssuers.init();

        identityStorage = new IdentityRegistryStorage();
        identityStorage.init();

        registry = new IdentityRegistry();
        registry.init(address(trustedIssuers), address(claimTopics), address(identityStorage));

        // The storage must accept writes from this registry, and the agent performs registrations.
        identityStorage.bindIdentityRegistry(address(registry));
        registry.addAgent(AGENT);

        issuer = new ClaimIssuerMock();

        // The rule under test consults the real registry. ERC-3643 defaults: receiver-only.
        rule = new RuleIdentityRegistry(ADMIN, address(registry), false, false);
        ruleEngine = new RuleEngine(ADMIN, address(0));
        ruleEngine.addRule(rule);
        vm.stopPrank();
    }

    /**
     * @dev Gives `wallet` an ONCHAINID and registers it with the ERC-3643 registry.
     */
    function _register(address wallet) internal returns (OnchainIdClaimMock id) {
        id = new OnchainIdClaimMock();
        identityOf[wallet] = id;
        vm.prank(AGENT);
        registry.registerIdentity(wallet, IIdentity(address(id)), COUNTRY_CH);
    }

    /**
     * @dev Switches the token to requiring one KYC claim from `issuer`.
     */
    function _requireKycClaim() internal {
        uint256[] memory topics = new uint256[](1);
        topics[0] = CLAIM_TOPIC_KYC;
        vm.startPrank(ADMIN);
        claimTopics.addClaimTopic(CLAIM_TOPIC_KYC);
        trustedIssuers.addTrustedIssuer(IClaimIssuer(address(issuer)), topics);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
        Regime 1 — no claim topics required
    //////////////////////////////////////////////////////////////*/

    function testWiringPointsAtTheRealRegistry() public view {
        assertEq(address(rule.identityRegistry()), address(registry));
    }

    function testUnregisteredReceiverIsRejected() public view {
        // No identity registered at all: the reference registry returns false, the rule maps that
        // onto its own restriction code, and the engine surfaces it.
        assertFalse(registry.isVerified(BOB));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
        assertFalse(ruleEngine.canTransfer(ALICE, BOB, 10));
    }

    function testRegisteredReceiverPassesWhenNoClaimsAreRequired() public {
        _register(BOB);
        assertTrue(registry.isVerified(BOB), "no required topics => a registered identity is verified");
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);
        assertTrue(ruleEngine.canTransfer(ALICE, BOB, 10));
    }

    function testSenderNeedNotBeRegistered() public {
        // ERC-3643 screens only the receiver; this is what lets a de-listed holder exit.
        _register(BOB);
        assertFalse(registry.isVerified(ALICE), "premise: the sender is unregistered");
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);
    }

    function testDeleteIdentityImmediatelyBlocksTheReceiver() public {
        _register(BOB);
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);

        vm.prank(AGENT);
        registry.deleteIdentity(BOB);

        assertFalse(registry.isVerified(BOB));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    /*//////////////////////////////////////////////////////////////
        Regime 2 — one required claim topic
    //////////////////////////////////////////////////////////////*/

    function testRegisteredButUnclaimedReceiverIsRejected() public {
        _register(BOB);
        _requireKycClaim();

        // Registered, but holds no KYC claim: the registry now walks the claim path and fails.
        assertFalse(registry.isVerified(BOB), "a required topic with no claim must fail");
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    function testReceiverWithAValidClaimPasses() public {
        OnchainIdClaimMock id = _register(BOB);
        _requireKycClaim();
        id.addClaim(CLAIM_TOPIC_KYC, address(issuer));

        assertTrue(registry.isVerified(BOB), "claim from a trusted issuer must verify");
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);
    }

    function testRevokingTheClaimBlocksTheReceiver() public {
        OnchainIdClaimMock id = _register(BOB);
        _requireKycClaim();
        id.addClaim(CLAIM_TOPIC_KYC, address(issuer));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);

        // The issuer invalidates its claims — the registry asks it, so the answer flips.
        issuer.setClaimsValid(false);

        assertFalse(registry.isVerified(BOB));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    function testClaimFromAnUntrustedIssuerDoesNotVerify() public {
        OnchainIdClaimMock id = _register(BOB);
        _requireKycClaim();

        // A claim on the right topic, but signed by an issuer the registry does not trust.
        ClaimIssuerMock rogue = new ClaimIssuerMock();
        id.addClaim(CLAIM_TOPIC_KYC, address(rogue));

        assertFalse(registry.isVerified(BOB), "only trusted issuers count");
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    /*//////////////////////////////////////////////////////////////
        The rule's opt-in flags against the real registry
    //////////////////////////////////////////////////////////////*/

    function testCheckSenderOptInScreensTheSenderToo() public {
        OnchainIdClaimMock bobId = _register(BOB);
        _requireKycClaim();
        bobId.addClaim(CLAIM_TOPIC_KYC, address(issuer));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);

        vm.prank(ADMIN);
        rule.setCheckSender(true);

        // ALICE is unregistered, so the stricter screening now rejects the same transfer.
        assertFalse(registry.isVerified(ALICE));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), 55); // CODE_ADDRESS_FROM_NOT_VERIFIED

        OnchainIdClaimMock aliceId = _register(ALICE);
        aliceId.addClaim(CLAIM_TOPIC_KYC, address(issuer));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, BOB, 10), TRANSFER_OK);
    }

    function testCheckSpenderOptInScreensTheSpender() public {
        OnchainIdClaimMock bobId = _register(BOB);
        _requireKycClaim();
        bobId.addClaim(CLAIM_TOPIC_KYC, address(issuer));

        // Default: the spender is not screened.
        assertEq(ruleEngine.detectTransferRestrictionFrom(SPENDER, ALICE, BOB, 10), TRANSFER_OK);

        vm.prank(ADMIN);
        rule.setCheckSpender(true);
        assertEq(ruleEngine.detectTransferRestrictionFrom(SPENDER, ALICE, BOB, 10), 57); // SPENDER_NOT_VERIFIED

        OnchainIdClaimMock spenderId = _register(SPENDER);
        spenderId.addClaim(CLAIM_TOPIC_KYC, address(issuer));
        assertEq(ruleEngine.detectTransferRestrictionFrom(SPENDER, ALICE, BOB, 10), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
        Mint / burn against the real registry
    //////////////////////////////////////////////////////////////*/

    function testMintIsScreenedOnTheReceiverOnly() public {
        OnchainIdClaimMock id = _register(BOB);
        _requireKycClaim();
        id.addClaim(CLAIM_TOPIC_KYC, address(issuer));

        // from == address(0): the registry is never asked about the sentinel.
        assertFalse(registry.isVerified(address(0)), "the sentinel is not a wallet");
        assertEq(ruleEngine.detectTransferRestriction(address(0), BOB, 10), TRANSFER_OK);

        // ...and an unverified recipient still blocks the mint.
        assertEq(ruleEngine.detectTransferRestriction(address(0), CAROL, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    function testBurnBypassesEligibility() public {
        // ERC-3643: "The `burn` function bypasses all checks on eligibility."
        _requireKycClaim();
        assertFalse(registry.isVerified(ALICE));
        assertEq(ruleEngine.detectTransferRestriction(ALICE, address(0), 10), TRANSFER_OK);
    }
}
