// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {ERC3643TokenMock, IERC3643ComplianceForToken} from "src/mocks/ERC3643TokenMock.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {
    IdentityRegistryWhitelistInvariantStorage
} from "src/registry/abstract/IdentityRegistryWhitelistInvariantStorage.sol";
import {IIdentityRegistryERC3643} from "src/registry/interfaces/IIdentityRegistryERC3643.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";

/**
 * @title Integration test: ERC-3643 token -> RuleEngine (as compliance) -> RuleWhitelist
 * @notice The RuleEngine occupies the token's **compliance** slot (`setCompliance`), not its
 *         identity-registry slot, so a CMTAT rule library can enforce an ERC-3643 token's transfer
 *         policy. The identity-registry slot is filled separately by `IdentityRegistryWhitelist`,
 *         which lets each test show which of the two slots is doing the blocking.
 *
 *         Wiring, transcribed from `Token.setCompliance` (`Token.sol:515-522`): the token calls
 *         `bindToken(address(this))` on the compliance contract **itself**, so the engine needs
 *         `setTokenSelfBindingApproval(token, true)` beforehand. That path exists in
 *         `TokenBindingExtendedModule._authorizeTokenBindingChange` specifically for
 *         ERC-3643 compatibility.
 */
contract ERC3643RuleEngineWhitelist is Test, HelperContract, IdentityRegistryWhitelistInvariantStorage {
    address constant AGENT = address(10);
    address constant INVESTOR = address(11);
    address constant INVESTOR2 = address(12);
    address constant OUTSIDER = address(14);

    IdentityRegistryWhitelist private registry;
    RuleWhitelist private whitelistRule;
    RuleEngine private engine;
    ERC3643TokenMock private token;

    function setUp() public {
        // ---- identity registry slot -------------------------------------------------
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry = new IdentityRegistryWhitelist(DEFAULT_ADMIN_ADDRESS);

        // ---- compliance slot: RuleEngine + RuleWhitelist -----------------------------
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);

        // The engine is deployed before the token exists, so it is bound afterwards.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engine.addRule(whitelistRule);

        token = new ERC3643TokenMock(IIdentityRegistryERC3643(address(registry)), AGENT);

        // Allow the token's self-binding call inside setCompliance.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engine.setTokenSelfBindingApproval(address(token), true);
        token.setCompliance(IERC3643ComplianceForToken(address(engine)));

        // ---- populate both slots ----------------------------------------------------
        bytes32 registrarRole = registry.IDENTITY_REGISTRAR_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry.grantRole(registrarRole, AGENT);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry.grantRole(registrarRole, address(token));

        // Everyone below is identity-verified, so any rejection comes from the RuleEngine.
        vm.startPrank(AGENT);
        registry.registerIdentity(INVESTOR, address(0), 0);
        registry.registerIdentity(INVESTOR2, address(0), 0);
        registry.registerIdentity(OUTSIDER, address(0), 0);
        vm.stopPrank();

        // ...but only INVESTOR and INVESTOR2 are on the compliance whitelist.
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.addAddress(INVESTOR);
        whitelistRule.addAddress(INVESTOR2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              WIRING
    //////////////////////////////////////////////////////////////*/

    function testWiring() public view {
        assertEq(address(token.compliance()), address(engine), "engine is the compliance contract");
        assertTrue(engine.isTokenBound(address(token)), "token bound to the engine");
        assertEq(address(token.identityRegistry()), address(registry), "registry is separate");
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `mint` asks the engine `canTransfer(address(0), to, amount)`, so the whitelist rule
     *         must allow mint. `allowMint` is false here, so minting is rejected by the RULE even
     *         though the recipient is identity-verified.
     */
    function testMint_RejectedWhenTheRuleForbidsMinting() public {
        vm.prank(AGENT);
        vm.expectRevert("Compliance not followed");
        token.mint(INVESTOR, 100);
    }

    function testMint_AllowedOnceTheRulePermitsMinting() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.setAllowMint(true);

        vm.prank(AGENT);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    /*//////////////////////////////////////////////////////////////
                              TRANSFER
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) private {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.setAllowMint(true);
        vm.prank(AGENT);
        token.mint(to, amount);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.setAllowMint(false);
    }

    function testTransfer_BetweenWhitelistedHolders() public {
        _mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        assertTrue(token.transfer(INVESTOR2, 40));
        assertEq(token.balanceOf(INVESTOR2), 40);
    }

    /**
     * @notice The decisive case: OUTSIDER is identity-verified, so the registry lets the transfer
     *         through, and it is the RuleEngine's whitelist rule that rejects it.
     */
    function testTransfer_RejectedByTheRuleEvenWhenIdentityVerified() public {
        _mint(INVESTOR, 100);
        assertTrue(registry.isVerified(OUTSIDER), "identity slot would allow it");
        assertFalse(whitelistRule.isAddressListed(OUTSIDER), "compliance slot will not");

        vm.prank(INVESTOR);
        vm.expectRevert("Transfer not possible");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OUTSIDER, 40);
    }

    /**
     * @notice And the mirror image: whitelisted by the rule but not identity-verified. Confirms the
     *         two slots are enforced independently rather than one masking the other.
     */
    function testTransfer_RejectedByTheRegistryEvenWhenRuleWhitelisted() public {
        _mint(INVESTOR, 100);

        address ruleOnly = address(15);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.addAddress(ruleOnly);
        assertFalse(registry.isVerified(ruleOnly));

        vm.prank(INVESTOR);
        vm.expectRevert("Transfer not possible");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ruleOnly, 40);
    }

    function testTransferFrom_GoesThroughTheEngineToo() public {
        _mint(INVESTOR, 100);

        vm.prank(OUTSIDER);
        assertTrue(token.transferFrom(INVESTOR, INVESTOR2, 30));

        vm.prank(OUTSIDER);
        vm.expectRevert("Transfer not possible");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(INVESTOR, OUTSIDER, 30);
    }

    /**
     * @notice Removing an address from the rule blocks it immediately — the engine is consulted on
     *         every transfer, not cached.
     */
    function testTransfer_BlockedAfterTheRecipientIsRemovedFromTheRule() public {
        _mint(INVESTOR, 100);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.removeAddress(INVESTOR2);

        vm.prank(INVESTOR);
        vm.expectRevert("Transfer not possible");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(INVESTOR2, 40);
    }

    /*//////////////////////////////////////////////////////////////
                           FORCED TRANSFER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `forcedTransfer` never calls `canTransfer` — it only notifies `transferred`
     *         afterwards. Because a RuleEngine **reverts** in `transferred` when a rule rejects,
     *         the agent still cannot force tokens onto a non-whitelisted address. The revert comes
     *         from the rule, not from the token's own "Transfer not possible" branch.
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

    /**
     * @notice `burn` calls only `destroyed`, never `canTransfer`. With `allowBurn` false the rule
     *         rejects it through that notification.
     */
    function testBurn_BlockedByTheRuleWhenBurningIsNotAllowed() public {
        _mint(INVESTOR, 100);

        vm.prank(AGENT);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(whitelistRule),
                INVESTOR,
                ZERO_ADDRESS,
                100,
                CODE_BURN_NOT_ALLOWED
            )
        );
        token.burn(INVESTOR, 100);
    }

    function testBurn_AllowedOnceTheRulePermitsBurning() public {
        _mint(INVESTOR, 100);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        whitelistRule.setAllowBurn(true);

        vm.prank(AGENT);
        token.burn(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 0);
        assertEq(token.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          ENGINE BOOKKEEPING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The engine only accepts `transferred` / `created` / `destroyed` from a bound token,
     *         so an arbitrary caller cannot drive rule state through it.
     */
    function testEngineRejectsCallbacksFromAnUnboundCaller() public {
        vm.prank(ATTACKER);
        vm.expectRevert();
        engine.transferred(INVESTOR, INVESTOR2, 1);
    }
}
