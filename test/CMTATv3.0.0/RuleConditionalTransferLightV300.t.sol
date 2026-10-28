// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title RuleConditionalTransferLight on CMTAT v3.0.0
 * @notice The rule acts on the token it is bound to; behind a RuleEngine the engine is also bound
 * (`bindRuleEngine`), since the engine is then the caller of `transferred`. Mint and burn need no approval.
 */
abstract contract RuleConditionalTransferLightV300Test is CMTATv300TestBase {
    RuleConditionalTransferLight internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        _attach(address(rule));
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        if (_viaEngine()) {
            rule.bindRuleEngine(address(engine));
        }
        vm.stopPrank();
        _mint(ADDRESS1, 100);
    }

    function testCannotTransferWithoutApproval() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, CODE_TRANSFER_REQUEST_NOT_APPROVED);
        vm.expectRevert(TransferNotApproved.selector);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testApprovedTransferConsumesTheApproval() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
        vm.expectRevert(TransferNotApproved.selector);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testApprovedTransferFromConsumesTheApproval() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(ADDRESS1, ADDRESS2, 10);
        _transferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
    }

    function testApproveAndTransferIfAllowed() public {
        _approve(ADDRESS1, address(rule), 10);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
        assertEq(rule.approvedCount(ADDRESS1, ADDRESS2, 10), 0);
    }

    function testMintAndBurnNeedNoApproval() public {
        _mint(ADDRESS2, 10);
        _burn(ADDRESS2, 10);
        assertEq(token.totalSupply(), 100);
    }
}

contract RuleConditionalTransferLightV300StandardDirectTest is
    RuleConditionalTransferLightV300Test,
    V300StandardDirect
{}

contract RuleConditionalTransferLightV300StandardEngineTest is
    RuleConditionalTransferLightV300Test,
    V300StandardEngine
{}

contract RuleConditionalTransferLightV300DebtDirectTest is RuleConditionalTransferLightV300Test, V300DebtDirect {}

contract RuleConditionalTransferLightV300DebtEngineTest is RuleConditionalTransferLightV300Test, V300DebtEngine {}
