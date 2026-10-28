// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {
    RuleSpenderWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleSpenderWhitelistInvariantStorage.sol";

/**
 * @title RuleSpenderWhitelist on CMTAT v3.0.0
 * @notice `transferFrom` reaches the rule with the caller as spender; direct transfers, mints and burns pass.
 */
abstract contract RuleSpenderWhitelistV300Test is CMTATv300TestBase {
    uint8 constant CODE_SPENDER = 66;
    RuleSpenderWhitelist internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS2);
        _attach(address(rule));
        _mint(ADDRESS1, 100);
    }

    function testTransferFromWithListedSpender() public {
        _assertCodeFrom(ADDRESS2, ADDRESS1, ADDRESS3, 10, TRANSFER_OK);
        _transferFrom(ADDRESS2, ADDRESS1, ADDRESS3, 10);
        assertEq(token.balanceOf(ADDRESS3), 10);
    }

    function testCannotTransferFromWithUnlistedSpender() public {
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_SPENDER);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleSpenderWhitelistInvariantStorage.RuleSpenderWhitelist_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testDirectTransferMintAndBurnPass() public {
        _transfer(ADDRESS1, ADDRESS3, 10);
        _mint(ADDRESS3, 5);
        _burn(ADDRESS3, 15);
        assertEq(token.balanceOf(ADDRESS3), 0);
    }
}

contract RuleSpenderWhitelistV300StandardDirectTest is RuleSpenderWhitelistV300Test, V300StandardDirect {}

contract RuleSpenderWhitelistV300StandardEngineTest is RuleSpenderWhitelistV300Test, V300StandardEngine {}

contract RuleSpenderWhitelistV300DebtDirectTest is RuleSpenderWhitelistV300Test, V300DebtDirect {}

contract RuleSpenderWhitelistV300DebtEngineTest is RuleSpenderWhitelistV300Test, V300DebtEngine {}
