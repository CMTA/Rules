// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../HelperContract.sol";
import "CMTAT/mocks/MinimalForwarderMock.sol";
import "../utils/SanctionListOracle.sol";
import {RuleSanctionsList, ISanctionsList} from "src/rules/validation/RuleSanctionsList.sol";
import {AccessControlModuleStandalone} from "../../src/modules/AccessControlModuleStandalone.sol";
/**
 * @title General functions of the ruleSanctionList
 */

contract RuleSanctionListDeploymentTest is Test, HelperContract {
    RuleSanctionsList ruleSanctionList;
    SanctionListOracle sanctionlistOracle;

    event Testa();

    // Arrange
    function setUp() public {}

    function testRightDeployment() public {
        // Arrange
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        MinimalForwarderMock forwarder = new MinimalForwarderMock();
        forwarder.initialize(ERC2771ForwarderDomain);
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        ruleSanctionList =
            new RuleSanctionsList(SANCTIONLIST_OPERATOR_ADDRESS, address(forwarder), ISanctionsList(ZERO_ADDRESS));

        // assert
        resBool = ruleSanctionList.hasRole(SANCTIONLIST_ROLE, SANCTIONLIST_OPERATOR_ADDRESS);
        assertEq(resBool, true);
        resBool = ruleSanctionList.isTrustedForwarder(address(forwarder));
        assertEq(resBool, true);
    }

    function testCannotDeployContractIfAdminAddressIsZero() public {
        // Arrange
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        MinimalForwarderMock forwarder = new MinimalForwarderMock();
        forwarder.initialize(ERC2771ForwarderDomain);
        vm.expectRevert(AccessControlModuleStandalone.AccessControlModuleStandalone_AddressZeroNotAllowed.selector);
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        ruleSanctionList = new RuleSanctionsList(address(0), address(forwarder), ISanctionsList(ZERO_ADDRESS));
    }

    function testCanSetAnOracleAtDeployment() public {
        sanctionlistOracle = new SanctionListOracle();
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        // TODO: Event seems not checked by Foundry at deployment
        emit SetSanctionListOracle(sanctionlistOracle);

        ruleSanctionList = new RuleSanctionsList(SANCTIONLIST_OPERATOR_ADDRESS, ZERO_ADDRESS, sanctionlistOracle);
        assertEq(address(ruleSanctionList.sanctionsList()), address(sanctionlistOracle));
    }
}
