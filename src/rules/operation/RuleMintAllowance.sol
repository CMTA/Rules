// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {AccessControlModuleStandalone} from "../../modules/AccessControlModuleStandalone.sol";
import {RuleMintAllowanceBase} from "./abstract/RuleMintAllowanceBase.sol";
import {ERC3643ComplianceRolesStorage} from "RuleEngine/modules/library/ERC3643ComplianceRolesStorage.sol";

/**
 * @title RuleMintAllowance
 * @notice AccessControl variant of RuleMintAllowance.
 *         `DEFAULT_ADMIN_ROLE` implicitly holds all roles.
 *         `ALLOWANCE_OPERATOR_ROLE` can set, increase, and decrease per-minter allowances.
 *         `COMPLIANCE_MANAGER_ROLE` can bind/unbind the rule to a RuleEngine.
 */
contract RuleMintAllowance is AccessControlModuleStandalone, RuleMintAllowanceBase, ERC3643ComplianceRolesStorage {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address of the contract admin.
     */
    constructor(address admin) AccessControlModuleStandalone(admin) {}

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, IERC165)
        returns (bool)
    {
        // Do not advertise full ERC-3643 ICompliance: its 3-arg mint callback
        // cannot identify the minter, so quota enforcement needs the spender-aware path.
        return interfaceId == RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID
            || interfaceId == ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_INTERFACE_ID || interfaceId == type(IERC7551Compliance).interfaceId
            || AccessControlEnumerable.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reverts unless the caller holds `COMPLIANCE_MANAGER_ROLE`.
     */
    function _onlyComplianceManager() internal view virtual override onlyRole(COMPLIANCE_MANAGER_ROLE) {}

    /**
     * @notice Reverts unless the caller holds `ALLOWANCE_OPERATOR_ROLE`.
     */
    function _authorizeSetMintAllowance() internal view virtual override onlyRole(ALLOWANCE_OPERATOR_ROLE) {}

    /**
     * @notice Reverts unless the caller holds `COMPLIANCE_MANAGER_ROLE`.
     */
    function _authorizeTokenBindingChange(address) internal view virtual override onlyRole(COMPLIANCE_MANAGER_ROLE) {}
}
