// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";

/**
 * @title RuleBlacklist on CMTAT v3.0.0
 * @notice WARNING: v3.0.0 forwards no spender on mint/burn, so a blacklisted MINTER is not screened
 * (on CMTAT >= v3.3 it is). Holders and `transferFrom` spenders are screened as usual.
 */
abstract contract RuleBlacklistV300Test is CMTATv300TestBase {
    RuleBlacklist internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        _attach(address(rule));
        _mint(ADDRESS1, 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS3);
    }

    function testTransferBetweenUnlisted() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferToBlacklisted() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_ADDRESS_TO_IS_BLACKLISTED);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testCannotTransferFromBlacklisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        _assertCode(ADDRESS1, ADDRESS2, 10, CODE_ADDRESS_FROM_IS_BLACKLISTED);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferFromWithBlacklistedSpender() public {
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_ADDRESS_SPENDER_IS_BLACKLISTED);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testCannotMintToBlacklisted() public {
        vm.expectPartialRevert(RuleBlacklist_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    function testCannotBurnFromBlacklisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransfer.selector);
        _burn(ADDRESS1, 10);
    }

    /// @notice v3.0.0 limitation: the minter is never forwarded, so blacklisting it does not stop it.
    function testBlacklistedMinterIsNotScreenedOnV300() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(DEFAULT_ADMIN_ADDRESS);
        _mint(ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }
}

contract RuleBlacklistV300StandardDirectTest is RuleBlacklistV300Test, V300StandardDirect {}

contract RuleBlacklistV300StandardEngineTest is RuleBlacklistV300Test, V300StandardEngine {}

contract RuleBlacklistV300DebtDirectTest is RuleBlacklistV300Test, V300DebtDirect {}

contract RuleBlacklistV300DebtEngineTest is RuleBlacklistV300Test, V300DebtEngine {}
