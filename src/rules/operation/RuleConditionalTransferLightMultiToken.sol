// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ComplianceInterfaceId} from "RuleEngine/modules/library/ComplianceInterfaceId.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {AccessControlModuleStandalone} from "../../modules/AccessControlModuleStandalone.sol";
import {RuleConditionalTransferLightMultiTokenBase} from "./abstract/RuleConditionalTransferLightMultiTokenBase.sol";
import {ERC3643ComplianceRolesStorage} from "RuleEngine/modules/library/ERC3643ComplianceRolesStorage.sol";

/**
 * @title RuleConditionalTransferLightMultiToken
 * @notice AccessControl variant of the multi-token conditional transfer rule.
 *         `OPERATOR_ROLE` approves transfers; `COMPLIANCE_MANAGER_ROLE` manages compliance bindings.
 */
contract RuleConditionalTransferLightMultiToken is
    AccessControlModuleStandalone,
    RuleConditionalTransferLightMultiTokenBase,
    ERC3643ComplianceRolesStorage
{
    /**
     * @param admin Address of the contract admin.
     */
    constructor(address admin) AccessControlModuleStandalone(admin) {}

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
        return interfaceId == RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID
            || interfaceId == ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_INTERFACE_ID || interfaceId == type(IERC7551Compliance).interfaceId
            || interfaceId == ComplianceInterfaceId.ERC3643_COMPLIANCE_INTERFACE_ID
            || AccessControlEnumerable.supportsInterface(interfaceId);
    }

    /**
     * @notice Reverts unless the caller holds `COMPLIANCE_MANAGER_ROLE`.
     */
    function _onlyComplianceManager() internal view virtual override onlyRole(COMPLIANCE_MANAGER_ROLE) {}

    /**
     * @notice Reverts unless the caller holds `OPERATOR_ROLE`.
     */
    function _authorizeTransferApproval() internal view virtual override onlyRole(OPERATOR_ROLE) {}
}
