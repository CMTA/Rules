// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";
import {RuleMaxTotalSupplyBase} from "../abstract/base/RuleMaxTotalSupplyBase.sol";

/**
 * @title RuleMaxTotalSupplyOwnable2Step
 * @notice Ownable2Step variant of RuleMaxTotalSupply.
 */
contract RuleMaxTotalSupplyOwnable2Step is RuleMaxTotalSupplyBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the owner, the token contract and the initial maximum supply.
     * @param owner Contract owner.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param maxTotalSupply_ Initial maximum supply.
     */
    constructor(address owner, address tokenContract_, uint256 maxTotalSupply_)
        RuleMaxTotalSupplyBase(tokenContract_, maxTotalSupply_)
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
     * @notice Restricts maximum total supply management to the contract owner.
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual override onlyOwner {}
}
