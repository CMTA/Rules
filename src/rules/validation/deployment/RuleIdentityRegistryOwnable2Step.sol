// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";
import {RuleIdentityRegistryBase} from "../abstract/base/RuleIdentityRegistryBase.sol";

/**
 * @title RuleIdentityRegistryOwnable2Step
 * @notice Ownable2Step variant of RuleIdentityRegistry.
 */
contract RuleIdentityRegistryOwnable2Step is RuleIdentityRegistryBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the owner and the ERC-3643 identity registry.
     * @dev Pass `false, false` for the ERC-3643-conformant default: the spec requires only the
     *      RECEIVER to be verified. The two flags below are stricter-than-spec opt-ins.
     * @param owner Contract owner.
     * @param identityRegistry_ Address of the ERC-3643 identity registry to query.
     * @param checkSender_ When true, also require the sender to be verified. Stricter than
     *        ERC-3643, and it traps de-listed holders: a holder whose identity lapses can no
     *        longer exit their position. Defaults to false.
     * @param checkSpender_ When true, also require the `transferFrom` spender to be verified.
     *        Mint and burn stay exempt from this check. Defaults to false.
     */
    constructor(address owner, address identityRegistry_, bool checkSender_, bool checkSpender_)
        RuleIdentityRegistryBase(identityRegistry_, checkSender_, checkSpender_)
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
     * @notice Restricts identity registry management to the contract owner.
     */
    function _authorizeIdentityRegistryManager() internal view virtual override onlyOwner {}
}
