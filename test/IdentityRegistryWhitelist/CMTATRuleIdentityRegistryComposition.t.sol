// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";

/**
 * @title CMTATRuleIdentityRegistryComposition
 * @notice End-to-end test of the two halves of this library's identity story working together:
 *         `RuleIdentityRegistry` *consults* an identity registry, `IdentityRegistryWhitelist` *is*
 *         one. Chain under test:
 *
 *         `CMTAT -> RuleEngine -> RuleIdentityRegistry -> IdentityRegistryWhitelist`
 *
 * @dev Until now each half was only ever tested against the other side's stand-in:
 *      `RuleIdentityRegistry` against `IdentityRegistryMock`, and `IdentityRegistryWhitelist` inside
 *      an **ERC-3643** token's identity slot. This suite closes that gap.
 *
 *      It matters more than a routine composition test, because **CMTAT has no
 *      `setIdentityRegistry` slot** -- that is an ERC-3643 concept. For a CMTAT token this chain is
 *      not one option among several, it is the *only* way to use `IdentityRegistryWhitelist` at all,
 *      and this library exists to serve CMTAT.
 *
 *      Note the two contracts are wired by interface, not by inheritance: the rule holds an
 *      `IIdentityRegistryVerified` and only ever calls `isVerified(address)`, which the registry
 *      implements as part of its ERC-3643 surface. Nothing in either contract references the other.
 */
contract CMTATRuleIdentityRegistryComposition is Test, HelperContract {
    IdentityRegistryWhitelist private registry;
    RuleIdentityRegistry private rule;

    address private constant REGISTRAR = address(20);
    address private constant MINTER = address(21);
    address private constant BURNER = address(22);
    address private constant SPENDER = address(23);

    function setUp() public {
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        // The registry IS an identity registry...
        registry = new IdentityRegistryWhitelist(DEFAULT_ADMIN_ADDRESS);
        registry.grantRole(registry.IDENTITY_REGISTRAR_ROLE(), REGISTRAR);

        // ...and the rule CONSULTS it. ERC-3643 defaults: receiver-only screening.
        rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, false);

        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
        ruleEngineMock.addRule(rule);
        cmtatContract.setRuleEngine(ruleEngineMock);

        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);
        cmtatContract.grantRole(keccak256("BURNER_ROLE"), BURNER);
        vm.stopPrank();
    }

    function _register(address user) internal {
        vm.prank(REGISTRAR);
        registry.registerIdentity(user, address(0xADD1), 756);
    }

    function _delist(address user) internal {
        vm.prank(REGISTRAR);
        registry.deleteIdentity(user);
    }

    /*//////////////////////////////////////////////////////////////
                            Wiring
    //////////////////////////////////////////////////////////////*/

    function testTheRuleReadsTheRegistryItWasGiven() public {
        assertEq(address(rule.identityRegistry()), address(registry), "rule must point at the registry");

        // A registration made on the registry is immediately visible through the rule and the engine.
        assertEq(ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
        _register(ADDRESS2);
        assertEq(ruleEngineMock.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        assertTrue(registry.isVerified(ADDRESS2));
    }

    /*//////////////////////////////////////////////////////////////
                        Mint / transfer / burn
    //////////////////////////////////////////////////////////////*/

    function testMintToARegisteredWalletSucceeds() public {
        _register(ADDRESS1);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 100);
    }

    function testMintToAnUnregisteredWalletReverts() public {
        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 0);
    }

    function testMintSucceedsEvenThoughTheMinterIsNotRegistered() public {
        // ERC-3643: mint "only require[s] the receiver to be whitelisted and verified".
        _register(ADDRESS1);
        assertFalse(registry.isVerified(MINTER), "premise: the minter is NOT registered");
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 100);
    }

    function testTransferBetweenRegisteredWalletsSucceeds() public {
        _register(ADDRESS1);
        _register(ADDRESS2);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(ADDRESS1);
        cmtatContract.transfer(ADDRESS2, 40);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 40);
    }

    function testTransferToAnUnregisteredWalletReverts() public {
        _register(ADDRESS1);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(ADDRESS1);
        vm.expectRevert();
        cmtatContract.transfer(ADDRESS2, 40);
    }

    function testBurnBypassesEligibility() public {
        // ERC-3643: "The `burn` function bypasses all checks on eligibility."
        _register(ADDRESS1);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        _delist(ADDRESS1);
        assertFalse(registry.isVerified(ADDRESS1), "premise: holder is de-listed");

        vm.prank(BURNER);
        cmtatContract.burn(ADDRESS1, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 0);
    }

    /*//////////////////////////////////////////////////////////////
        The de-listed holder can still exit (invariant I-1)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The property the whole receiver-only design exists for, exercised against the real
     *         registry rather than a mock: an investor whose identity is deleted can still sell out
     *         to a verified counterparty, but can no longer receive.
     */
    function testDelistedHolderCanStillSendButNotReceive() public {
        _register(ADDRESS1);
        _register(ADDRESS2);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        _delist(ADDRESS1);

        // Can still SEND to a verified counterparty — the exit is open.
        vm.prank(ADDRESS1);
        cmtatContract.transfer(ADDRESS2, 60);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 60);

        // Can no longer RECEIVE.
        vm.prank(ADDRESS2);
        vm.expectRevert();
        cmtatContract.transfer(ADDRESS1, 10);
    }

    /*//////////////////////////////////////////////////////////////
                    Zero address is never verified
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `isVerified(address(0))` must be false (invariant I-12), and that must not break mint
     *         or burn — the rule never asks the registry about the sentinel.
     */
    function testZeroAddressIsNeverVerifiedAndMintBurnStillWork() public {
        assertFalse(registry.isVerified(ZERO_ADDRESS), "the sentinel is not a wallet");

        _register(ADDRESS1);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100); // from == address(0)
        vm.prank(BURNER);
        cmtatContract.burn(ADDRESS1, 100); // to == address(0)
        assertEq(cmtatContract.balanceOf(ADDRESS1), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    Opt-in stricter screening
    //////////////////////////////////////////////////////////////*/

    function testCheckSenderOptInTrapsTheDelistedHolder() public {
        // Documented consequence of the opt-in: enabling it removes the exit.
        _register(ADDRESS1);
        _register(ADDRESS2);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSender(true);
        _delist(ADDRESS1);

        vm.prank(ADDRESS1);
        vm.expectRevert();
        cmtatContract.transfer(ADDRESS2, 10);
    }

    function testCheckSpenderOptInScreensTheSpenderOnTransferFrom() public {
        _register(ADDRESS1);
        _register(ADDRESS2);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(ADDRESS1);
        cmtatContract.approve(SPENDER, 50);

        // Default: the spender is not screened, so an unregistered spender may move funds.
        assertFalse(registry.isVerified(SPENDER));
        vm.prank(SPENDER);
        cmtatContract.transferFrom(ADDRESS1, ADDRESS2, 10);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 10);

        // Opt in, and the same call is now rejected until the spender is registered.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSpender(true);

        vm.prank(SPENDER);
        vm.expectRevert();
        cmtatContract.transferFrom(ADDRESS1, ADDRESS2, 10);

        _register(SPENDER);
        vm.prank(SPENDER);
        cmtatContract.transferFrom(ADDRESS1, ADDRESS2, 10);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 20);
    }

    /*//////////////////////////////////////////////////////////////
                    Registry writes reach the token
    //////////////////////////////////////////////////////////////*/

    function testRegistrarRoleGatesTheWholeChain() public {
        // Nobody but the registrar can make a wallet transferable.
        vm.expectRevert();
        vm.prank(ADDRESS3);
        registry.registerIdentity(ADDRESS1, address(0xADD1), 756);

        assertEq(ruleEngineMock.detectTransferRestriction(ADDRESS3, ADDRESS1, 10), CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    function testDeleteIdentityImmediatelyBlocksInboundTransfers() public {
        _register(ADDRESS1);
        _register(ADDRESS2);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);

        vm.prank(ADDRESS1);
        cmtatContract.transfer(ADDRESS2, 10);

        _delist(ADDRESS2);

        vm.prank(ADDRESS1);
        vm.expectRevert();
        cmtatContract.transfer(ADDRESS2, 10);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 10, "balance unchanged after the rejected transfer");
    }
}
