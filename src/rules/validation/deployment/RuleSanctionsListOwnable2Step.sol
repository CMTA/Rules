// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {ERC2771Context} from "../../../modules/MetaTxModuleStandalone.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";
import {RuleSanctionsListBase} from "../abstract/base/RuleSanctionsListBase.sol";
import {ISanctionsList} from "../../interfaces/ISanctionsList.sol";

/**
 * @title RuleSanctionsListOwnable2Step
 * @notice Ownable2Step variant of RuleSanctionsList.
 */
contract RuleSanctionsListOwnable2Step is RuleSanctionsListBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the owner, the forwarder and the sanctions oracle.
     * @param owner Contract owner.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder for meta-transactions.
     * @param sanctionContractOracle_ Chainalysis sanctions oracle used to screen addresses.
     */
    constructor(address owner, address forwarderIrrevocable, ISanctionsList sanctionContractOracle_)
        RuleSanctionsListBase(forwarderIrrevocable, sanctionContractOracle_)
        Ownable(owner)
    {}

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Indicates whether this contract supports a given interface.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(RuleTransferValidation, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts sanctions list management to the contract owner.
     */
    function _authorizeSanctionListManager() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the message sender, accounting for meta-transaction (ERC-2771) context.
     * @return sender The address of the message sender.
     */
    function _msgSender() internal view virtual override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @notice Returns the message calldata, accounting for meta-transaction (ERC-2771) context.
     * @return The message calldata.
     */
    function _msgData() internal view virtual override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @notice Returns the length of the context suffix appended by the forwarder.
     * @return The context suffix length in bytes.
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
