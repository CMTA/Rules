// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable2StepERC165Module} from "../../modules/Ownable2StepERC165Module.sol";
import {RuleTransferValidation} from "../validation/abstract/core/RuleTransferValidation.sol";
import {RuleIssuanceCapBase} from "./abstract/RuleIssuanceCapBase.sol";

/**
 * @title RuleIssuanceCapOwnable2Step
 * @notice Ownable2Step variant of RuleIssuanceCap: the owner changes the cap and binds the caller.
 */
contract RuleIssuanceCapOwnable2Step is RuleIssuanceCapBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param tokenContract_ Token whose mints are capped; fixed for the life of the rule.
     * @param issuanceCap_ Maximum cumulative issuance, in token base units (scaled by `10 ** decimals()`).
     * @param initialIssued_ Issuance before the rule was installed; at least the token's current supply.
     */
    constructor(address owner, address tokenContract_, uint256 issuanceCap_, uint256 initialIssued_)
        RuleIssuanceCapBase(tokenContract_, issuanceCap_, initialIssued_)
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
     * @notice Restricts cap management to the owner.
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts binding management to the owner.
     */
    function _onlyComplianceManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts bind / unbind to the owner.
     */
    function _authorizeTokenBindingChange(address) internal view virtual override onlyOwner {}
}
