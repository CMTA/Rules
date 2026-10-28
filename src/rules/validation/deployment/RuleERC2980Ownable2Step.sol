// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleERC2980Base} from "../abstract/base/RuleERC2980Base.sol";

/**
 * @title RuleERC2980Ownable2Step
 * @notice Ownable2Step variant of RuleERC2980 with owner-based authorization hooks.
 * @dev All whitelist and frozenlist management functions are restricted to the contract owner.
 */
contract RuleERC2980Ownable2Step is RuleERC2980Base, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder for meta-transactions.
     * @param allowMintBurn When true, permits both minting and burning (sets `allowMint` and `allowBurn`).
     */
    constructor(address owner, address forwarderIrrevocable, bool allowMintBurn)
        RuleERC2980Base(forwarderIrrevocable, allowMintBurn)
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
        override(RuleERC2980Base, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId) || RuleERC2980Base.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts toggling `allowMint` / `allowBurn` to the contract owner.
     */
    function _authorizeMintBurnManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts adding addresses to the whitelist to the contract owner.
     */
    function _authorizeWhitelistAdd() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts removing addresses from the whitelist to the contract owner.
     */
    function _authorizeWhitelistRemove() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts adding addresses to the frozenlist to the contract owner.
     */
    function _authorizeFrozenlistAdd() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts removing addresses from the frozenlist to the contract owner.
     */
    function _authorizeFrozenlistRemove() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the message sender, accounting for meta-transaction (ERC-2771) context.
     * @return sender The address of the message sender.
     */
    function _msgSender() internal view virtual override(Context, RuleERC2980Base) returns (address sender) {
        return super._msgSender();
    }

    /**
     * @notice Returns the message calldata, accounting for meta-transaction (ERC-2771) context.
     * @return The message calldata.
     */
    function _msgData() internal view virtual override(Context, RuleERC2980Base) returns (bytes calldata) {
        return super._msgData();
    }

    /**
     * @notice Returns the length of the context suffix appended by the forwarder.
     * @return The context suffix length in bytes.
     */
    function _contextSuffixLength() internal view virtual override(Context, RuleERC2980Base) returns (uint256) {
        return super._contextSuffixLength();
    }
}
