// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {
    AccessControlEnumerableTestBase,
    IAccessControlEnumerableLike
} from "../utils/AccessControlEnumerableTestBase.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";

contract RuleMaxTotalSupplyAccessControlRoleMembers is AccessControlEnumerableTestBase {
    function _deployAccessControl() internal override returns (IAccessControlEnumerableLike, address) {
        address adminAddr = DEFAULT_ADMIN_ADDRESS;
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(adminAddr, address(new TotalSupplyMock()), 1000);
        return (IAccessControlEnumerableLike(address(rule)), adminAddr);
    }

    function testRoleMembers() public {
        address[] memory singleAdmin = new address[](1);
        singleAdmin[0] = admin;

        _assertRoleMembers(DEFAULT_ADMIN_ROLE, singleAdmin);
        // The admin holds MAX_TOTAL_SUPPLY_ROLE implicitly but is not enumerated as a member.
        _assertRoleMembers(keccak256("MAX_TOTAL_SUPPLY_ROLE"), new address[](0));
    }
}
