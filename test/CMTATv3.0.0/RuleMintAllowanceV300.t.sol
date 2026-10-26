// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";

/**
 * @title RuleMintAllowance on CMTAT v3.0.0 -- NOT SUPPORTED
 * @notice Pins the incompatibility. The rule debits the minter's quota on the 4-argument `transferred`, but
 * v3.0.0 sends every mint on the 3-argument one, with no minter. The rule is therefore inert: it blocks
 * nothing and debits nothing, while its own views still report the quota. Requires CMTAT >= v3.3.
 */
abstract contract RuleMintAllowanceV300Test is CMTATv300TestBase {
    RuleMintAllowance internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        _attach(address(rule));
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(_ruleCaller());
        rule.setMintAllowance(DEFAULT_ADMIN_ADDRESS, 5);
        vm.stopPrank();
    }

    function testMintAboveTheQuotaIsNotBlockedOnV300() public {
        assertFalse(rule.canTransferFrom(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ADDRESS1, 100), "rule view says no");
        _mint(ADDRESS1, 100);
        assertEq(token.balanceOf(ADDRESS1), 100);
        assertEq(rule.mintAllowance(DEFAULT_ADMIN_ADDRESS), 5, "quota never debited");
    }
}

contract RuleMintAllowanceV300StandardDirectTest is RuleMintAllowanceV300Test, V300StandardDirect {}

contract RuleMintAllowanceV300StandardEngineTest is RuleMintAllowanceV300Test, V300StandardEngine {}

contract RuleMintAllowanceV300DebtDirectTest is RuleMintAllowanceV300Test, V300DebtDirect {}

contract RuleMintAllowanceV300DebtEngineTest is RuleMintAllowanceV300Test, V300DebtEngine {}
