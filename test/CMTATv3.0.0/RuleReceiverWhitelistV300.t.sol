// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {
    RuleReceiverWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleReceiverWhitelistInvariantStorage.sol";

/**
 * @title RuleReceiverWhitelist on CMTAT v3.0.0
 * @notice Only the receiver is screened, so a de-listed holder can still exit; burns are exempt.
 */
abstract contract RuleReceiverWhitelistV300Test is CMTATv300TestBase {
    uint8 constant CODE_RECEIVER = 90;
    RuleReceiverWhitelist internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        rule.addAddress(ADDRESS2);
        vm.stopPrank();
        _attach(address(rule));
        _mint(ADDRESS1, 100);
    }

    function testTransferToListedReceiver() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferToUnlistedReceiver() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_RECEIVER);
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testDelistedHolderCanStillExit() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddress(ADDRESS1);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testUnlistedSpenderIsNotScreened() public {
        _transferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testCannotMintToUnlistedReceiver() public {
        _assertCode(ZERO_ADDRESS, ADDRESS3, 10, CODE_RECEIVER);
        vm.expectPartialRevert(RuleReceiverWhitelistInvariantStorage.RuleReceiverWhitelist_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    function testBurnIsExempt() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddress(ADDRESS1);
        _burn(ADDRESS1, 10);
        assertEq(token.totalSupply(), 90);
    }
}

contract RuleReceiverWhitelistV300StandardDirectTest is RuleReceiverWhitelistV300Test, V300StandardDirect {}

contract RuleReceiverWhitelistV300StandardEngineTest is RuleReceiverWhitelistV300Test, V300StandardEngine {}

contract RuleReceiverWhitelistV300DebtDirectTest is RuleReceiverWhitelistV300Test, V300DebtDirect {}

contract RuleReceiverWhitelistV300DebtEngineTest is RuleReceiverWhitelistV300Test, V300DebtEngine {}
