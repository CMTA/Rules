// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../HelperContract.sol";
import "RuleEngine/RuleEngine.sol";

/**
 * @title Integration test with the CMTAT
 */
contract RuleBlacklistTest is Test, HelperContract {
    // Arrange
    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
    }

    function testCanRuleBlacklistReturnMessageNotFoundWithUnknownCodeId() public view {
        // Act
        string memory message1 = ruleBlacklist.messageForTransferRestriction(255);

        // Assert
        assertEq(message1, TEXT_CODE_NOT_FOUND);
    }

    function testDetectTransferRestrictionOk() public {
        // Act
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // Act
        resBool = ruleBlacklist.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, true);
        // Act
        resBool = ruleBlacklist.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, true);
    }

    function testDetectTransferRestrictionFRom() public {
        // Arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);
        // Act
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_FROM_IS_BLACKLISTED);

        // With tokenId
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_FROM_IS_BLACKLISTED);

        // Act
        resBool = ruleBlacklist.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertFalse(resBool);

        // Act
        resBool = ruleBlacklist.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertFalse(resBool);
    }

    function testDetectTransferRestrictionTO() public {
        // Arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);

        // With tokenId
        resUint8 = ruleBlacklist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_IS_BLACKLISTED);

        // Act
        resBool = ruleBlacklist.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertFalse(resBool);

        // Act
        resBool = ruleBlacklist.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertFalse(resBool);
    }
}
