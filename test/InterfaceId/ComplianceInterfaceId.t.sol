// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ComplianceInterfaceId} from "RuleEngine/modules/library/ComplianceInterfaceId.sol";

import {IERC3643ComplianceFull} from "src/mocks/IERC3643ComplianceFull.sol";

/**
 * @title ComplianceInterfaceIdTest
 * @notice Pins the ERC-3643 ICompliance interface ID the operation rules advertise.
 * @dev RuleEngine v3.0.0-rc6 derives {ComplianceInterfaceId-ERC3643_COMPLIANCE_INTERFACE_ID} from
 *      its own interface hierarchy instead of hardcoding it, so a refactor upstream -- such as the
 *      rc6 split of the binding functions into `ITokenBinding` -- can now move the value silently.
 *      These assertions are the guard: the constant must stay equal to the flattened redeclaration
 *      in {IERC3643ComplianceFull} and to the literal wire value.
 */
contract ComplianceInterfaceIdTest is Test {
    function testConstantMatchesFlattenedInterface() public pure {
        assertEq(
            ComplianceInterfaceId.ERC3643_COMPLIANCE_INTERFACE_ID,
            type(IERC3643ComplianceFull).interfaceId,
            "upstream derivation diverged from the flattened ERC-3643 ICompliance surface"
        );
    }

    function testConstantMatchesWireValue() public pure {
        assertEq(ComplianceInterfaceId.ERC3643_COMPLIANCE_INTERFACE_ID, bytes4(0x3144991c), "wire value moved");
    }
}
