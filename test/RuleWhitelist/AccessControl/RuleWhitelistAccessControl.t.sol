// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../HelperContract.sol";

/**
 * @title Tests on the Access Control
 */
contract RuleWhitelistAccessControl is Test, HelperContract {
    // Custom error openZeppelin
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    // Arrange
    function setUp() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist = new RuleWhitelist(
            WHITELIST_OPERATOR_ADDRESS,
            ZERO_ADDRESS
        );
    }

    function testCannotAttackeraddAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                ATTACKER,
                ADDRESS_LIST_ADD_ROLE
            )
        );
        vm.prank(ATTACKER);
        ruleWhitelist.addAddress(ADDRESS1);

        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, false);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }

    function testCannotAttackeraddAddresses() public {
        // Arrange
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                ATTACKER,
                ADDRESS_LIST_ADD_ROLE
            )
        );
        vm.prank(ATTACKER);
        (resCallBool, ) = address(ruleWhitelist).call(
            abi.encodeWithSignature(
                "addAddresses(address[])",
                whitelist
            )
        );

        // Assert
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, false);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, false);
        resBool = ruleWhitelist.isAddressListed(ADDRESS3);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }

    function testCannotAttackerremoveAddress() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                ATTACKER,
                ADDRESS_LIST_REMOVE_ROLE
            )
        );
        vm.prank(ATTACKER);
        ruleWhitelist.removeAddress(ADDRESS1);

        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 1);
    }

    function testCannotAttackerremoveAddresses() public {
        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool, ) = address(ruleWhitelist).call(
            abi.encodeWithSignature(
                "addAddresses(address[])",
                whitelist
            )
        );
        assertEq(resCallBool, true);
        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                ATTACKER,
                ADDRESS_LIST_REMOVE_ROLE
            )
        );
        vm.prank(ATTACKER);
        (resCallBool, ) = address(ruleWhitelist).call(
            abi.encodeWithSignature(
                "removeAddresses(address[])",
                whitelist
            )
        );
        // Assert
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 2);
    }
}
