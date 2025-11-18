// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../HelperContract.sol";

/**
 * @title Tests the functions to remove addresses from the whitelist
 */
contract RuleWhitelistRemoveTest is Test, HelperContract {
    // Arrange
    function setUp() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true);
    }

    function _addAddresses() internal {
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit AddAddresses(whitelist);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        // Assert
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 2);
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);
    }

    function testRemoveAddress() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit RemoveAddress(ADDRESS1);
        ruleWhitelist.removeAddress(ADDRESS1);

        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }

    function testRemoveAddressWhenArrayContainSeveralAddresses() public {
        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        assertEq(resCallBool, true);
        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit RemoveAddresses(whitelist);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("removeAddresses(address[])", whitelist));
        // Assert
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }

    function testRemoveAddressNotPresentFromTheWhitelist() public {
        // Arrange
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        vm.expectRevert(RuleAddressSet_AddressNotFound.selector);

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit RemoveAddress(ADDRESS1);
        ruleWhitelist.removeAddress(ADDRESS1);

        // Assert
        // no change
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
    }

    function testRemoveAddressesNotPresentFromTheWhitelist() public {
        // Arrange
        _addAddresses();
        // Arrange
        address[] memory whitelistRemove = new address[](3);
        whitelistRemove[0] = ADDRESS1;
        whitelistRemove[1] = ADDRESS2;
        // Target Address - Not Present in the whitelist
        whitelistRemove[2] = ADDRESS3;

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit RemoveAddresses(whitelistRemove);
        (resCallBool,) =
            address(ruleWhitelist).call(abi.encodeWithSignature("removeAddresses(address[])", whitelistRemove));
        // Assert
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }
}
