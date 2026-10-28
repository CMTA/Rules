// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ComplianceNotFollowed, Token, TransferNotPossible} from "ERC3643/token/Token.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {
    RuleWhitelistInvariantStorage
} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleWhitelistInvariantStorage.sol";

/**
 * @title Integration test against the REAL vendored ERC-3643 token
 * @notice Everything else in this repository exercises `ERC3643TokenMock`, whose call sequences are
 *         transcribed from `Token.sol`. This suite deploys the genuine `Token` from
 *         `lib/ERC-3643/` (4.2.0-beta1) and drives the same two slots through it:
 *
 *             real ERC-3643 Token ── compliance slot ──▶ RuleEngine ──▶ RuleWhitelist
 *                                 └─ identity slot ────▶ IdentityRegistryWhitelist
 *
 *         Its value is precisely that nothing here is transcribed: if upstream changes when the
 *         token consults compliance or the registry, these tests break and the mock's fidelity
 *         claim is re-checked for free.
 *
 * @dev Built by a dedicated profile because `Token.sol` pins `pragma solidity 0.8.30` exactly,
 *      which cannot share a compilation unit with the project's 0.8.34. This file therefore also
 *      pins 0.8.30 (our own contracts are `^0.8.20`, so they compile at it happily). Run with:
 *
 *          FOUNDRY_PROFILE=erc3643 forge test
 *
 *      `test/ERC3643Real/**` is in the default profile's `skip` list so the ordinary `forge test`
 *      is unaffected.
 */
contract ERC3643RealTokenRuleEngine is Test, RuleWhitelistInvariantStorage {
    address constant ADMIN = address(1);
    address constant AGENT = address(10);
    address constant INVESTOR = address(11);
    address constant INVESTOR2 = address(12);
    address constant OUTSIDER = address(14);

    IdentityRegistryWhitelist private registry;
    RuleWhitelist private whitelistRule;
    RuleEngine private engine;
    Token private token;

    function setUp() public {
        vm.startPrank(ADMIN);
        registry = new IdentityRegistryWhitelist(ADMIN);
        whitelistRule = new RuleWhitelist(ADMIN, address(0), false, false);
        engine = new RuleEngine(ADMIN, address(0));
        engine.addRule(whitelistRule);
        vm.stopPrank();

        // The real token self-binds to its compliance inside `init`/`setCompliance`.
        token = new Token();
        vm.prank(ADMIN);
        engine.setTokenSelfBindingApproval(address(token), true);

        token.init(address(registry), address(engine), "Real ERC-3643", "R3643", 0, address(0));

        // `init` leaves the token paused and makes the deployer its owner.
        token.addAgent(AGENT);
        vm.prank(AGENT);
        token.unpause();

        bytes32 registrarRole = registry.IDENTITY_REGISTRAR_ROLE();
        vm.startPrank(ADMIN);
        registry.grantRole(registrarRole, AGENT);
        registry.grantRole(registrarRole, address(token));
        vm.stopPrank();

        // Identity-verify everyone, so any rejection below comes from the RuleEngine.
        vm.startPrank(AGENT);
        registry.registerIdentity(INVESTOR, address(0), 0);
        registry.registerIdentity(INVESTOR2, address(0), 0);
        registry.registerIdentity(OUTSIDER, address(0), 0);
        vm.stopPrank();

        // ...but only INVESTOR and INVESTOR2 pass the compliance whitelist.
        vm.startPrank(ADMIN);
        whitelistRule.addAddress(INVESTOR);
        whitelistRule.addAddress(INVESTOR2);
        vm.stopPrank();
    }

    /**
     * @notice Mints through the real token with the rule's mint gate open.
     */
    function _mint(address to, uint256 amount) private {
        vm.prank(ADMIN);
        whitelistRule.setAllowMint(true);
        vm.prank(AGENT);
        token.mint(to, amount);
        vm.prank(ADMIN);
        whitelistRule.setAllowMint(false);
    }

    /*//////////////////////////////////////////////////////////////
                                WIRING
    //////////////////////////////////////////////////////////////*/

    function testWiring() public view {
        assertEq(address(token.compliance()), address(engine), "engine is the compliance contract");
        assertEq(address(token.identityRegistry()), address(registry), "registry is the identity slot");
        assertTrue(engine.isTokenBound(address(token)), "token bound to the engine");
        assertEq(token.symbol(), "R3643");
    }

    /*//////////////////////////////////////////////////////////////
                                 MINT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The real `mint` requires `compliance.canTransfer(address(0), to, amount)`, so the
     *         whitelist rule's `allowMint` flag gates issuance.
     */
    function testMint_RejectedWhenTheRuleForbidsMinting() public {
        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 0);
    }

    function testMint_AllowedOnceTheRulePermitsMinting() public {
        _mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
        assertEq(token.totalSupply(), 100);
    }

    /*//////////////////////////////////////////////////////////////
                               TRANSFER
    //////////////////////////////////////////////////////////////*/

    function testTransfer_BetweenWhitelistedHolders() public {
        _mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        assertTrue(token.transfer(INVESTOR2, 40));
        assertEq(token.balanceOf(INVESTOR2), 40);
        assertEq(token.balanceOf(INVESTOR), 60);
    }

    /**
     * @notice The decisive case: OUTSIDER passes the identity registry, so it is the RuleEngine's
     *         whitelist rule that blocks the transfer — proving the compliance slot is live on the
     *         real token, not merely wired.
     */
    function testTransfer_RejectedByTheRuleEvenWhenIdentityVerified() public {
        _mint(INVESTOR, 100);
        assertTrue(registry.isVerified(OUTSIDER), "identity slot would allow it");
        assertFalse(whitelistRule.isAddressListed(OUTSIDER), "compliance slot will not");

        // The token's own error: `canTransfer` returned false, so it never reached `transferred`.
        vm.prank(INVESTOR);
        vm.expectRevert(TransferNotPossible.selector);
        token.transfer(OUTSIDER, 40);
        assertEq(token.balanceOf(OUTSIDER), 0);
    }

    /**
     * @notice The mirror image: on the rule's whitelist but not identity-verified. Together with
     *         the previous test this shows the two slots are enforced independently.
     */
    function testTransfer_RejectedByTheRegistryEvenWhenRuleWhitelisted() public {
        _mint(INVESTOR, 100);

        address ruleOnly = address(15);
        vm.prank(ADMIN);
        whitelistRule.addAddress(ruleOnly);
        assertFalse(registry.isVerified(ruleOnly));

        vm.prank(INVESTOR);
        vm.expectRevert(TransferNotPossible.selector);
        token.transfer(ruleOnly, 40);
        assertEq(token.balanceOf(ruleOnly), 0);
    }

    function testTransfer_BlockedAfterTheRecipientIsRemovedFromTheRule() public {
        _mint(INVESTOR, 100);

        vm.prank(ADMIN);
        whitelistRule.removeAddress(INVESTOR2);

        vm.prank(INVESTOR);
        vm.expectRevert(TransferNotPossible.selector);
        token.transfer(INVESTOR2, 40);
    }

    function testTransferFrom_GoesThroughTheEngineToo() public {
        _mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        token.approve(OUTSIDER, 100);

        vm.prank(OUTSIDER);
        assertTrue(token.transferFrom(INVESTOR, INVESTOR2, 30));
        assertEq(token.balanceOf(INVESTOR2), 30);

        vm.prank(OUTSIDER);
        vm.expectRevert(TransferNotPossible.selector);
        token.transferFrom(INVESTOR, OUTSIDER, 30);
    }

    /*//////////////////////////////////////////////////////////////
                            FORCED TRANSFER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `forcedTransfer` never consults `canTransfer` — it only notifies `transferred`. A
     *         RuleEngine reverts inside that notification, so an agent still cannot force tokens
     *         onto a non-whitelisted address. Verified here against the real token rather than
     *         inferred from the mock.
     */
    function testForcedTransfer_StillBlockedByTheRuleViaTransferred() public {
        _mint(INVESTOR, 100);

        vm.prank(AGENT);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(whitelistRule),
                INVESTOR,
                OUTSIDER,
                40,
                CODE_ADDRESS_TO_NOT_WHITELISTED
            )
        );
        token.forcedTransfer(INVESTOR, OUTSIDER, 40);
        assertEq(token.balanceOf(OUTSIDER), 0);
    }

    function testForcedTransfer_AllowedToAWhitelistedHolder() public {
        _mint(INVESTOR, 100);

        vm.prank(AGENT);
        assertTrue(token.forcedTransfer(INVESTOR, INVESTOR2, 60));
        assertEq(token.balanceOf(INVESTOR2), 60);
    }

    /*//////////////////////////////////////////////////////////////
                                 BURN
    //////////////////////////////////////////////////////////////*/

    function testBurn_BlockedByTheRuleWhenBurningIsNotAllowed() public {
        _mint(INVESTOR, 100);

        vm.prank(AGENT);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(whitelistRule),
                INVESTOR,
                address(0),
                100,
                CODE_BURN_NOT_ALLOWED
            )
        );
        token.burn(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testBurn_AllowedOnceTheRulePermitsBurning() public {
        _mint(INVESTOR, 100);

        vm.prank(ADMIN);
        whitelistRule.setAllowBurn(true);

        vm.prank(AGENT);
        token.burn(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 0);
        assertEq(token.totalSupply(), 0);
    }
}
