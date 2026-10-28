// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";
import {RuleMaxBalanceBase} from "../abstract/base/RuleMaxBalanceBase.sol";

/**
 * @title RuleMaxBalanceOwnable2Step
 * @notice Ownable2Step variant of RuleMaxBalance.
 * @dev WARNING: pair this with a rule that admits one address per investor. The cap counts tokens per
 * address, so a holder with several addresses can otherwise exceed it.
 */
contract RuleMaxBalanceOwnable2Step is RuleMaxBalanceBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the owner, the observed token and the initial cap.
     * @param owner Contract owner.
     * @param balanceToken_ Token contract that exposes `balanceOf` (must be a contract).
     * @param maxBalance_ Initial maximum balance per non-exempt address.
     */
    constructor(address owner, address balanceToken_, uint256 maxBalance_)
        RuleMaxBalanceBase(balanceToken_, maxBalance_)
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
     * @notice Restricts cap, token and exemption management to the contract owner.
     */
    function _authorizeMaxBalanceManager() internal view virtual override onlyOwner {}
}
