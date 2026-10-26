// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase, ICMTATv300} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300DebtDirect} from "./CMTATv300Variants.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {
    RuleConditionalTransferLightMultiTokenInvariantStorage
} from "src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenInvariantStorage.sol";

/**
 * @title RuleConditionalTransferLightMultiToken on CMTAT v3.0.0
 * @notice Direct binding only (Topology B): approvals are consumed under `msg.sender`, so this rule must not
 * sit behind a RuleEngine. No engine suites exist for that reason. One instance serves two v3.0.0 tokens.
 */
abstract contract RuleConditionalTransferLightMultiTokenV300Test is CMTATv300TestBase {
    RuleConditionalTransferLightMultiToken internal rule;
    ICMTATv300 internal tokenB;

    function setUp() public {
        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        _deployToken();
        tokenB = token;
        _attach(address(rule));
        _deployToken();
        _attach(address(rule));
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        rule.bindToken(address(tokenB));
        tokenB.mint(ADDRESS1, 100);
        vm.stopPrank();
        _mint(ADDRESS1, 100);
    }

    function testCannotTransferWithoutApproval() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, CODE_TRANSFER_REQUEST_NOT_APPROVED);
        vm.expectRevert(
            RuleConditionalTransferLightMultiTokenInvariantStorage.RuleConditionalTransferLightMultiToken_TransferNotApproved
                .selector
        );
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testApprovalIsScopedToItsToken() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(token), ADDRESS1, ADDRESS2, 10);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(token), ADDRESS1, ADDRESS2, 10);
        vm.prank(ADDRESS1);
        vm.expectRevert(
            RuleConditionalTransferLightMultiTokenInvariantStorage.RuleConditionalTransferLightMultiToken_TransferNotApproved
                .selector
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        tokenB.transfer(ADDRESS2, 10);
    }

    function testApproveAndTransferIfAllowed() public {
        _approve(ADDRESS1, address(rule), 10);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(address(token), ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testMintAndBurnNeedNoApproval() public {
        _mint(ADDRESS2, 10);
        _burn(ADDRESS2, 10);
        assertEq(token.totalSupply(), 100);
    }
}

contract RuleConditionalTransferLightMultiTokenV300StandardDirectTest is
    RuleConditionalTransferLightMultiTokenV300Test,
    V300StandardDirect
{}

contract RuleConditionalTransferLightMultiTokenV300DebtDirectTest is
    RuleConditionalTransferLightMultiTokenV300Test,
    V300DebtDirect
{}
