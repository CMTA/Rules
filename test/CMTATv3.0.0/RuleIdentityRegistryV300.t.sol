// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";

/**
 * @title RuleIdentityRegistry on CMTAT v3.0.0
 * @notice ERC-3643 semantics: only the receiver must be verified; `checkSpender` screens `transferFrom`
 * spenders. The minter is exempt on every CMTAT version (ERC-3643: mint only requires the receiver).
 */
abstract contract RuleIdentityRegistryV300Test is CMTATv300TestBase {
    RuleIdentityRegistry internal rule;
    IdentityRegistryMock internal registry;

    function setUp() public {
        _deployToken();
        registry = new IdentityRegistryMock();
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, true);
        _attach(address(rule));
        _mint(ADDRESS1, 100);
    }

    function testTransferToVerifiedReceiver() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferToUnverifiedReceiver() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_ADDRESS_TO_NOT_VERIFIED);
        vm.expectPartialRevert(RuleIdentityRegistry_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testUnverifiedSenderCanStillExit() public {
        registry.setVerified(ADDRESS1, false);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testCannotTransferFromWithUnverifiedSpender() public {
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_ADDRESS_SPENDER_NOT_VERIFIED);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleIdentityRegistry_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testCannotMintToUnverifiedReceiver() public {
        vm.expectPartialRevert(RuleIdentityRegistry_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    /// @notice The unverified minter (the admin) mints to a verified receiver, even with `checkSpender = true`.
    function testUnverifiedMinterCanMintToVerifiedReceiver() public {
        _mint(ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testBurnBypassesEligibility() public {
        registry.setVerified(ADDRESS1, false);
        _burn(ADDRESS1, 10);
        assertEq(token.totalSupply(), 90);
    }
}

contract RuleIdentityRegistryV300StandardDirectTest is RuleIdentityRegistryV300Test, V300StandardDirect {}

contract RuleIdentityRegistryV300StandardEngineTest is RuleIdentityRegistryV300Test, V300StandardEngine {}

contract RuleIdentityRegistryV300DebtDirectTest is RuleIdentityRegistryV300Test, V300DebtDirect {}

contract RuleIdentityRegistryV300DebtEngineTest is RuleIdentityRegistryV300Test, V300DebtEngine {}
