// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleWhitelistBase} from "../abstract/base/RuleWhitelistBase.sol";
import {RuleAddressSet} from "../abstract/RuleAddressSet/RuleAddressSet.sol";

/**
 * @title RuleWhitelistOwnable2Step
 * @notice Ownable2Step variant of RuleWhitelist with owner-based authorization hooks.
 */
contract RuleWhitelistOwnable2Step is RuleWhitelistBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder.
     * @param checkSpender_ Enables spender checks for transferFrom when true.
     * @param allowMintBurn When true, permits both minting and burning (sets `allowMint` and `allowBurn`).
     */
    constructor(address owner, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistBase(forwarderIrrevocable, checkSpender_, allowMintBurn)
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
        override(RuleWhitelistBase, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleWhitelistBase.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts adding addresses to the whitelist to the contract owner.
     */
    function _authorizeAddressListAdd() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts removing addresses from the whitelist to the contract owner.
     */
    function _authorizeAddressListRemove() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts toggling the spender-check setting to the contract owner.
     */
    function _authorizeCheckSpenderManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts toggling `allowMint` / `allowBurn` to the contract owner.
     */
    function _authorizeMintBurnManager() internal view virtual override onlyOwner {}

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
