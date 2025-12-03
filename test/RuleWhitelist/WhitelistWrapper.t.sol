// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "CMTAT/deployment/CMTATStandalone.sol";
import "../HelperContract.sol";
import {AccessControlModuleStandalone} from "../../src/modules/AccessControlModuleStandalone.sol";
/**
 * @title Integration test with the CMTAT
 */

contract CMTATIntegrationWhitelistWrapper is Test, HelperContract {
    uint256 ADDRESS1_BALANCE_INIT = 31;
    uint256 ADDRESS2_BALANCE_INIT = 32;
    uint256 ADDRESS3_BALANCE_INIT = 33;

    uint256 FLAG = 5;
    RuleWhitelist ruleWhitelist2;
    RuleWhitelist ruleWhitelist3;
    RuleWhitelistWrapper ruleWhitelistWrapper;

    // Arrange
    function setUp() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true);
        ruleWhitelist2 = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true);
        ruleWhitelist3 = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true);
        ruleWhitelistWrapper = new RuleWhitelistWrapper(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist2);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelistWrapper.addRule(ruleWhitelist3);
    }

    /**
     * Deployment ******
     */
    function testCannotDeployContractIfAdminAddressIsZero() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        vm.expectRevert(AccessControlModuleStandalone.AccessControlModuleStandalone_AddressZeroNotAllowed.selector);
        ruleWhitelistWrapper = new RuleWhitelistWrapper(ZERO_ADDRESS, ZERO_ADDRESS, true);
    }

    function testReturnTheRightMessageForAGivenCode() public {
        // Assert
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
        // Act
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_TO_NOT_WHITELISTED);

        // Act
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resString = ruleWhitelistWrapper.messageForTransferRestriction(CODE_NONEXISTENT);
        // Assert
        assertEq(resString, TEXT_CODE_NOT_FOUND);
    }

    function testDetectTransferRestrictionFrom() public {
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelistWrapper.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, false);

        // Act
        resBool = ruleWhitelistWrapper.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, false);
    }

    function testDetectTransferRestrictionTo() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);
    }

    function testDetectTransferRestrictionWithSpender() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, false);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, false);
    }

    function testDetectTransferRestrictionOk() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);
    }

    function testDetectTransferRestrictionWithSpenderOk() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);
        // Act
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, true);

        // Act
        resBool = ruleWhitelistWrapper.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, true);

        // With tokenId
        resUint8 = ruleWhitelistWrapper.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);
    }

    
}
