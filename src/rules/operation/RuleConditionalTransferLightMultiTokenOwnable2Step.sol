// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ComplianceInterfaceId} from "RuleEngine/modules/library/ComplianceInterfaceId.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {RuleConditionalTransferLightMultiTokenBase} from "./abstract/RuleConditionalTransferLightMultiTokenBase.sol";
import {Ownable2StepERC165Module} from "../../modules/Ownable2StepERC165Module.sol";

/**
 * @title RuleConditionalTransferLightMultiTokenOwnable2Step
 * @notice Ownable2Step variant of the multi-token conditional transfer rule.
 *         The owner approves transfers and manages compliance bindings.
 */
contract RuleConditionalTransferLightMultiTokenOwnable2Step is
    RuleConditionalTransferLightMultiTokenBase,
    Ownable2Step,
    Ownable2StepERC165Module
{
    /**
     * @param owner Address of the contract owner.
     */
    constructor(address owner) Ownable(owner) {}

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Ownable2StepERC165Module, IERC165)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || interfaceId == RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID
            || interfaceId == ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_INTERFACE_ID || interfaceId == type(IERC7551Compliance).interfaceId
            || interfaceId == ComplianceInterfaceId.ERC3643_COMPLIANCE_INTERFACE_ID;
    }

    /**
     * @notice Reverts unless the caller is the owner.
     */
    function _onlyComplianceManager() internal view virtual override onlyOwner {}

    /**
     * @notice Reverts unless the caller is the owner.
     */
    function _authorizeTransferApproval() internal view virtual override onlyOwner {}
}
