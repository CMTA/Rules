// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {
    RuleERC2980InvariantStorage
} from "src/rules/validation/abstract/RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";

/**
 * @title RuleERC2980 on CMTAT v3.0.0
 * @notice Recipient whitelist plus frozenlist. WARNING: a frozen MINTER is not screened on v3.0.0, which
 * forwards no spender on mint.
 */
abstract contract RuleERC2980V300Test is CMTATv300TestBase {
    uint8 constant CODE_FROM_FROZEN = 60;
    uint8 constant CODE_TO_NOT_WHITELISTED = 63;
    uint8 constant CODE_SPENDER_FROZEN = 62;
    RuleERC2980 internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addWhitelistAddress(ADDRESS1);
        rule.addWhitelistAddress(ADDRESS2);
        vm.stopPrank();
        _attach(address(rule));
        _mint(ADDRESS1, 100);
    }

    function testTransferToWhitelistedRecipient() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferToNonWhitelistedRecipient() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_TO_NOT_WHITELISTED);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testCannotTransferFromFrozenSender() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addFrozenlistAddress(ADDRESS1);
        _assertCode(ADDRESS1, ADDRESS2, 10, CODE_FROM_FROZEN);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferFromWithFrozenSpender() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addFrozenlistAddress(ADDRESS3);
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_SPENDER_FROZEN);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testCannotMintToNonWhitelistedRecipient() public {
        vm.expectPartialRevert(RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    /// @notice v3.0.0 limitation: the minter is never forwarded, so freezing it does not stop it.
    function testFrozenMinterIsNotScreenedOnV300() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addFrozenlistAddress(DEFAULT_ADMIN_ADDRESS);
        _mint(ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }
}

contract RuleERC2980V300StandardDirectTest is RuleERC2980V300Test, V300StandardDirect {}

contract RuleERC2980V300StandardEngineTest is RuleERC2980V300Test, V300StandardEngine {}

contract RuleERC2980V300DebtDirectTest is RuleERC2980V300Test, V300DebtDirect {}

contract RuleERC2980V300DebtEngineTest is RuleERC2980V300Test, V300DebtEngine {}
