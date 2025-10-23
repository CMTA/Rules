// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../HelperContract.sol";
import "../utils/SanctionListOracle.sol";
import {RuleSanctionsList, ISanctionsList} from "src/rules/validation/RuleSanctionsList.sol";
/**
 * @title General functions of the ruleSanctionList
 */
contract RuleSanctionlistAddTest is Test, HelperContract {
    // Custom error openZeppelin
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    SanctionListOracle sanctionlistOracle;
    RuleSanctionsList ruleSanctionList;

    // Arrange
    function setUp() public {
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        sanctionlistOracle = new SanctionListOracle();
        sanctionlistOracle.addToSanctionsList(ATTACKER);
        ruleSanctionList = new RuleSanctionsList(
            SANCTIONLIST_OPERATOR_ADDRESS,
            ZERO_ADDRESS,
            ISanctionsList(ZERO_ADDRESS)
        );
    }

    function testCanSetandRemoveOracle() public {
        // ADD
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        emit SetSanctionListOracle(sanctionlistOracle);
        ruleSanctionList.setSanctionListOracle(sanctionlistOracle);

        ISanctionsList sanctionListOracleGet = ruleSanctionList.sanctionsList();
        // Assert
        vm.assertEq(
            address(sanctionListOracleGet),
            address(sanctionlistOracle)
        );
        // Remove
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        emit SetSanctionListOracle(ISanctionsList(ZERO_ADDRESS));
        ruleSanctionList.setSanctionListOracle(ISanctionsList(ZERO_ADDRESS));
        // Assert
        sanctionListOracleGet = ruleSanctionList.sanctionsList();
        vm.assertEq(address(sanctionListOracleGet), address(ZERO_ADDRESS));
    }

    function testCannotAttackerSetOracle() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                ATTACKER,
                SANCTIONLIST_ROLE
            )
        );
        ruleSanctionList.setSanctionListOracle(sanctionlistOracle);
    }
}
