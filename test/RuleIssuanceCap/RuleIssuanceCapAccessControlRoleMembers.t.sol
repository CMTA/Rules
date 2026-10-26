// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {
    AccessControlEnumerableTestBase,
    IAccessControlEnumerableLike
} from "../utils/AccessControlEnumerableTestBase.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";

contract RuleIssuanceCapAccessControlRoleMembers is AccessControlEnumerableTestBase {
    function _deployAccessControl() internal override returns (IAccessControlEnumerableLike, address) {
        RuleIssuanceCap rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(new TotalSupplyMock()), 1000, 0);
        return (IAccessControlEnumerableLike(address(rule)), DEFAULT_ADMIN_ADDRESS);
    }

    /// @notice Only the admin is enumerated; it holds the operational roles implicitly.
    function testRoleMembers() public {
        address[] memory singleAdmin = new address[](1);
        singleAdmin[0] = admin;
        _assertRoleMembers(DEFAULT_ADMIN_ROLE, singleAdmin);
        _assertRoleMembers(keccak256("MAX_TOTAL_SUPPLY_ROLE"), new address[](0));
        _assertRoleMembers(keccak256("COMPLIANCE_MANAGER_ROLE"), new address[](0));
        assertTrue(accessControl.hasRole(keccak256("MAX_TOTAL_SUPPLY_ROLE"), admin));
        assertTrue(accessControl.hasRole(keccak256("COMPLIANCE_MANAGER_ROLE"), admin));
    }
}
