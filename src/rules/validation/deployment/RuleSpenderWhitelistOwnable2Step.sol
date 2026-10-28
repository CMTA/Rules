// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleSpenderWhitelistBase} from "../abstract/base/RuleSpenderWhitelistBase.sol";
import {RuleAddressSet} from "../abstract/RuleAddressSet/RuleAddressSet.sol";

/**
 * @title RuleSpenderWhitelistOwnable2Step
 * @notice Ownable2Step deployment variant of spender whitelist rule.
 */
contract RuleSpenderWhitelistOwnable2Step is RuleSpenderWhitelistBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the owner and the meta-transaction forwarder.
     * @param owner Contract owner.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder for meta-transactions.
     */
    constructor(address owner, address forwarderIrrevocable)
        RuleSpenderWhitelistBase(forwarderIrrevocable)
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
        override(RuleSpenderWhitelistBase, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleSpenderWhitelistBase.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts adding addresses to the spender whitelist to the contract owner.
     */
    function _authorizeAddressListAdd() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts removing addresses from the spender whitelist to the contract owner.
     */
    function _authorizeAddressListRemove() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the message sender, accounting for meta-transaction (ERC-2771) context.
     * @return sender The address of the message sender.
     */
    function _msgSender() internal view virtual override(Context, RuleAddressSet) returns (address sender) {
        return super._msgSender();
    }

    /**
     * @notice Returns the message calldata, accounting for meta-transaction (ERC-2771) context.
     * @return The message calldata.
     */
    function _msgData() internal view virtual override(Context, RuleAddressSet) returns (bytes calldata) {
        return super._msgData();
    }

    /**
     * @notice Returns the length of the context suffix appended by the forwarder.
     * @return The context suffix length in bytes.
     */
    function _contextSuffixLength() internal view virtual override(Context, RuleAddressSet) returns (uint256) {
        return super._contextSuffixLength();
    }
}
