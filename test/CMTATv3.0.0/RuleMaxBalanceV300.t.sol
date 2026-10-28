// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {
    RuleMaxBalanceInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxBalanceInvariantStorage.sol";

/**
 * @title RuleMaxBalance on CMTAT v3.0.0
 * @notice v3.0.0 notifies before moving the value, so `balanceOf(to)` excludes the amount in flight.
 */
abstract contract RuleMaxBalanceV300Test is CMTATv300TestBase {
    uint8 constant CODE_MAX_BALANCE = 82;
    uint256 constant MAX = 50;
    RuleMaxBalance internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, address(token), MAX);
        _attach(address(rule));
        _mint(ADDRESS1, 50);
        _mint(ADDRESS2, 40);
    }

    function testTransferUpToTheCap() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), MAX);
    }

    function testCannotTransferAboveTheCap() public {
        _assertCode(ADDRESS1, ADDRESS2, 11, CODE_MAX_BALANCE);
        vm.expectPartialRevert(RuleMaxBalanceInvariantStorage.RuleMaxBalance_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS2, 11);
    }

    function testCannotTransferFromAboveTheCap() public {
        _approve(ADDRESS1, ADDRESS3, 11);
        vm.expectPartialRevert(RuleMaxBalanceInvariantStorage.RuleMaxBalance_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 11);
    }

    function testCannotMintAboveTheCap() public {
        _assertCode(ZERO_ADDRESS, ADDRESS2, 11, CODE_MAX_BALANCE);
        vm.expectPartialRevert(RuleMaxBalanceInvariantStorage.RuleMaxBalance_InvalidTransfer.selector);
        _mint(ADDRESS2, 11);
    }

    function testBurnIsNotCapped() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxBalance(0);
        _burn(ADDRESS1, 50);
        assertEq(token.balanceOf(ADDRESS1), 0);
    }
}

contract RuleMaxBalanceV300StandardDirectTest is RuleMaxBalanceV300Test, V300StandardDirect {}

contract RuleMaxBalanceV300StandardEngineTest is RuleMaxBalanceV300Test, V300StandardEngine {}

contract RuleMaxBalanceV300DebtDirectTest is RuleMaxBalanceV300Test, V300DebtDirect {}

contract RuleMaxBalanceV300DebtEngineTest is RuleMaxBalanceV300Test, V300DebtEngine {}
