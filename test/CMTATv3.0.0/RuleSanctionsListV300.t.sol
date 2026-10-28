// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";

/**
 * @title RuleSanctionsList on CMTAT v3.0.0
 * @notice WARNING: as for RuleBlacklist, a sanctioned MINTER is not screened on v3.0.0 (no spender forwarded).
 */
abstract contract RuleSanctionsListV300Test is CMTATv300TestBase {
    RuleSanctionsList internal rule;
    SanctionListOracle internal oracle;

    function setUp() public {
        _deployToken();
        oracle = new SanctionListOracle();
        rule = new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(address(oracle)));
        _attach(address(rule));
        _mint(ADDRESS1, 100);
        oracle.addToSanctionsList(ADDRESS3);
    }

    function testTransferBetweenUnsanctioned() public {
        _assertCode(ADDRESS1, ADDRESS2, 10, TRANSFER_OK);
        _transfer(ADDRESS1, ADDRESS2, 10);
    }

    function testCannotTransferToSanctioned() public {
        _assertCode(ADDRESS1, ADDRESS3, 10, CODE_ADDRESS_TO_IS_SANCTIONED);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        _transfer(ADDRESS1, ADDRESS3, 10);
    }

    function testCannotTransferFromWithSanctionedSpender() public {
        _assertCodeFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10, CODE_ADDRESS_SPENDER_IS_SANCTIONED);
        _approve(ADDRESS1, ADDRESS3, 10);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransferFrom.selector);
        _transferFromApproved(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testCannotMintToSanctioned() public {
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        _mint(ADDRESS3, 10);
    }

    /// @notice v3.0.0 limitation: the minter is never forwarded, so a sanctioned minter is not stopped.
    function testSanctionedMinterIsNotScreenedOnV300() public {
        oracle.addToSanctionsList(DEFAULT_ADMIN_ADDRESS);
        _mint(ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }
}

contract RuleSanctionsListV300StandardDirectTest is RuleSanctionsListV300Test, V300StandardDirect {}

contract RuleSanctionsListV300StandardEngineTest is RuleSanctionsListV300Test, V300StandardEngine {}

contract RuleSanctionsListV300DebtDirectTest is RuleSanctionsListV300Test, V300DebtDirect {}

contract RuleSanctionsListV300DebtEngineTest is RuleSanctionsListV300Test, V300DebtEngine {}
