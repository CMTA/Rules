// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

/**
 * @title RuleWhitelistWrapper on CMTAT v3.0.0
 * @notice An address is accepted when listed in ANY child whitelist (OR logic).
 */
abstract contract RuleWhitelistWrapperV300Test is CMTATv300TestBase {
    RuleWhitelistWrapper internal wrapper;
    RuleWhitelist internal childA;
    RuleWhitelist internal childB;

    function setUp() public {
        _deployToken();
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, true);
        childA = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        childB = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        childA.addAddress(ADDRESS1);
        childB.addAddress(ADDRESS2);
        wrapper.addRule(IRule(address(childA)));
        wrapper.addRule(IRule(address(childB)));
        vm.stopPrank();
        _attach(address(wrapper));
        _mint(ADDRESS1, 100);
    }

    function testTransferAcrossChildren() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    function testCannotTransferToAddressInNoChild() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_ADDRESS_TO_NOT_WHITELISTED);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testCannotTransferFromWithUnlistedSpender() public {
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testCannotMintToAddressInNoChild() public {
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    function testBurn() public {
        _burn(ADDRESS1, 10);
        assertEq(token.totalSupply(), 90);
    }
}

contract RuleWhitelistWrapperV300StandardDirectTest is RuleWhitelistWrapperV300Test, V300StandardDirect {}

contract RuleWhitelistWrapperV300StandardEngineTest is RuleWhitelistWrapperV300Test, V300StandardEngine {}

contract RuleWhitelistWrapperV300DebtDirectTest is RuleWhitelistWrapperV300Test, V300DebtDirect {}

contract RuleWhitelistWrapperV300DebtEngineTest is RuleWhitelistWrapperV300Test, V300DebtEngine {}
