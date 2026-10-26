// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";

/**
 * @title RuleWhitelist on CMTAT v3.0.0
 * @notice Mint and burn are gated by `allowMint` / `allowBurn`, never by a spender: v3.0.0 forwards none.
 */
abstract contract RuleWhitelistV300Test is CMTATv300TestBase {
    RuleWhitelist internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, true);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        rule.addAddress(ADDRESS2);
        vm.stopPrank();
        _attach(address(rule));
        _mint(ADDRESS1, 100);
    }

    function testTransferBetweenWhitelisted() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testCannotTransferToNonWhitelisted() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_ADDRESS_TO_NOT_WHITELISTED);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testCannotTransferFromWithNonWhitelistedSpender() public {
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testTransferFromWithWhitelistedSpender() public {
        _transferFrom(ADDRESS2, ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testCannotMintToNonWhitelisted() public {
        _assertCode(ZERO_ADDRESS, ADDRESS3, 10, CODE_ADDRESS_TO_NOT_WHITELISTED);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    function testMintAndBurnGatedByFlags() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.setAllowMint(false);
        rule.setAllowBurn(false);
        vm.stopPrank();
        _assertCode(ZERO_ADDRESS, ADDRESS1, 10, CODE_MINT_NOT_ALLOWED);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        _mint(ADDRESS1, 10);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        _burn(ADDRESS1, 10);
    }

    function testBurnFromWhitelisted() public {
        _burn(ADDRESS1, 40);
        assertEq(token.balanceOf(ADDRESS1), 60);
    }
}

contract RuleWhitelistV300StandardDirectTest is RuleWhitelistV300Test, V300StandardDirect {}

contract RuleWhitelistV300StandardEngineTest is RuleWhitelistV300Test, V300StandardEngine {}

contract RuleWhitelistV300DebtDirectTest is RuleWhitelistV300Test, V300DebtDirect {}

contract RuleWhitelistV300DebtEngineTest is RuleWhitelistV300Test, V300DebtEngine {}
