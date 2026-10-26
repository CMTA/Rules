// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Token} from "ERC3643/token/Token.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";

/**
 * @title Parity test: RuleReceiverWhitelist vs ERC-3643's own eligibility rule
 * @notice `RuleReceiverWhitelist` claims to reproduce ERC-3643's screening semantics — receiver
 *         only. This suite tests that claim the only way it can be tested honestly: run the rule
 *         in the **compliance** slot of the real vendored `Token.sol` over the *same address set*
 *         the identity registry holds, and assert the rule never changes the outcome.
 *
 *             real ERC-3643 Token ── compliance slot ──▶ RuleEngine ──▶ RuleReceiverWhitelist
 *                                 └─ identity slot ────▶ IdentityRegistryWhitelist   (same members)
 *
 *         If the rule screened the sender or the spender, the token would start rejecting
 *         transfers that stock ERC-3643 accepts, and these tests would fail. That makes this a
 *         real equivalence check rather than a restatement of the rule's own logic.
 *
 * @dev Built by the `erc3643` profile — see `foundry.toml`. Run with:
 *          FOUNDRY_PROFILE=erc3643 forge test
 */
contract ERC3643ReceiverWhitelistParity is Test {
    address constant ADMIN = address(1);
    address constant AGENT = address(10);
    address constant HOLDER = address(11);
    address constant ELIGIBLE = address(12);
    address constant OUTSIDER = address(14);

    IdentityRegistryWhitelist private registry;
    RuleReceiverWhitelist private receiverRule;
    RuleEngine private engine;
    Token private token;

    function setUp() public {
        vm.startPrank(ADMIN);
        registry = new IdentityRegistryWhitelist(ADMIN);
        receiverRule = new RuleReceiverWhitelist(ADMIN, address(0));
        engine = new RuleEngine(ADMIN, address(0));
        engine.addRule(receiverRule);
        vm.stopPrank();

        token = new Token();
        vm.prank(ADMIN);
        engine.setTokenSelfBindingApproval(address(token), true);
        token.init(address(registry), address(engine), "Parity", "PAR", 0, address(0));

        token.addAgent(AGENT);
        vm.prank(AGENT);
        token.unpause();

        bytes32 registrarRole = registry.IDENTITY_REGISTRAR_ROLE();
        vm.startPrank(ADMIN);
        registry.grantRole(registrarRole, AGENT);
        registry.grantRole(registrarRole, address(token));
        vm.stopPrank();

        // The SAME membership on both slots: HOLDER and ELIGIBLE in, OUTSIDER out.
        vm.startPrank(AGENT);
        registry.registerIdentity(HOLDER, address(0), 0);
        registry.registerIdentity(ELIGIBLE, address(0), 0);
        vm.stopPrank();
        vm.startPrank(ADMIN);
        receiverRule.addAddress(HOLDER);
        receiverRule.addAddress(ELIGIBLE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        THE RULE IS TRANSPARENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint to an eligible receiver: ERC-3643 allows it, so the rule must not block it.
     *         Note there is no `allowMint` flag to open — the rule gates mint on the receiver
     *         alone, exactly as ERC-3643 does.
     */
    function testMint_ToEligibleReceiverPassesBothSlots() public {
        vm.prank(AGENT);
        token.mint(HOLDER, 100);
        assertEq(token.balanceOf(HOLDER), 100);
    }

    function testTransfer_BetweenEligiblePartiesPasses() public {
        vm.prank(AGENT);
        token.mint(HOLDER, 100);

        vm.prank(HOLDER);
        assertTrue(token.transfer(ELIGIBLE, 40));
        assertEq(token.balanceOf(ELIGIBLE), 40);
    }

    /**
     * @notice The load-bearing test. A de-listed holder must still be able to exit — ERC-3643
     *         screens only the receiver precisely so a lapsed investor is not trapped. A rule that
     *         screened the sender would break this while every other test still passed.
     */
    function testDeListedHolderCanStillExit() public {
        vm.prank(AGENT);
        token.mint(HOLDER, 100);

        // Drop the sender from BOTH slots.
        vm.prank(AGENT);
        registry.deleteIdentity(HOLDER);
        vm.prank(ADMIN);
        receiverRule.removeAddress(HOLDER);

        assertFalse(registry.isVerified(HOLDER), "sender de-listed on the identity slot");
        assertFalse(receiverRule.isAddressListed(HOLDER), "sender de-listed on the compliance slot");

        // ...and the position is still movable to an eligible counterparty.
        vm.prank(HOLDER);
        assertTrue(token.transfer(ELIGIBLE, 100));
        assertEq(token.balanceOf(ELIGIBLE), 100);
    }

    /**
     * @notice `transferFrom` "works the same way" per ERC-3643: an unlisted spender is fine.
     */
    function testTransferFrom_UnlistedSpenderIsNotBlocked() public {
        vm.prank(AGENT);
        token.mint(HOLDER, 100);

        vm.prank(HOLDER);
        token.approve(OUTSIDER, 100);
        assertFalse(receiverRule.isAddressListed(OUTSIDER), "spender is not listed");

        vm.prank(OUTSIDER);
        assertTrue(token.transferFrom(HOLDER, ELIGIBLE, 30));
        assertEq(token.balanceOf(ELIGIBLE), 30);
    }

    /**
     * @notice `burn` bypasses eligibility in ERC-3643, so the rule must not block it either — even
     *         for a de-listed holder. The rule's burn exemption is what makes this pass; without
     *         it, `address(0)` would be an unlisted receiver and every burn would revert.
     */
    function testBurn_IsNotBlockedEvenForADeListedHolder() public {
        vm.prank(AGENT);
        token.mint(HOLDER, 100);

        vm.prank(AGENT);
        registry.deleteIdentity(HOLDER);
        vm.prank(ADMIN);
        receiverRule.removeAddress(HOLDER);

        vm.prank(AGENT);
        token.burn(HOLDER, 100);
        assertEq(token.balanceOf(HOLDER), 0);
        assertEq(token.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        AND IT STILL ENFORCES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transparency must not mean inertness: with the rule's list narrower than the
     *         registry's, the rule blocks. Proves the previous tests pass because the semantics
     *         agree, not because the rule is never consulted.
     */
    function testRuleStillBlocksWhenItsListIsNarrowerThanTheRegistry() public {
        vm.prank(AGENT);
        token.mint(HOLDER, 100);

        // OUTSIDER becomes identity-verified but is deliberately NOT added to the rule.
        vm.prank(AGENT);
        registry.registerIdentity(OUTSIDER, address(0), 0);
        assertTrue(registry.isVerified(OUTSIDER), "identity slot would allow it");

        vm.prank(HOLDER);
        vm.expectRevert();
        token.transfer(OUTSIDER, 40);
        assertEq(token.balanceOf(OUTSIDER), 0);
    }
}
