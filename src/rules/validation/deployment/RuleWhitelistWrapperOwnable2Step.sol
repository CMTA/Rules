// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/* ==== OpenZeppelin === */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
/* ==== Abstract contracts === */
import {RuleWhitelistWrapperBase} from "../abstract/base/RuleWhitelistWrapperBase.sol";

/**
 * @title Wrapper to call several different whitelist rules (Ownable2Step)
 */
contract RuleWhitelistWrapperOwnable2Step is RuleWhitelistWrapperBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param owner Address of the contract owner
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     * @param checkSpender_ Enables spender checks for transferFrom when true.
     * @param allowMintBurn When true, permits both minting and burning (sets `allowMint` and `allowBurn`).
     */
    constructor(address owner, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistWrapperBase(forwarderIrrevocable, checkSpender_, allowMintBurn)
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
        override(RuleWhitelistWrapperBase, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleWhitelistWrapperBase.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts toggling the spender-check setting to the contract owner.
     */
    function _authorizeCheckSpenderManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts toggling `allowMint` / `allowBurn` to the contract owner.
     */
    function _authorizeMintBurnManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts rules management to the contract owner.
     * @dev Restrict rules management to the owner.
     */
    function _onlyRulesManager() internal view virtual override onlyOwner {}

    /**
     * @notice Restricts rules-limit management to the contract owner.
     */
    function _onlyRulesLimitManager() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the message sender, accounting for meta-transaction (ERC-2771) context.
     * @return sender The address of the message sender.
     */
    function _msgSender() internal view virtual override(RuleWhitelistWrapperBase, Context) returns (address sender) {
        return RuleWhitelistWrapperBase._msgSender();
    }

    /**
     * @notice Returns the message calldata, accounting for meta-transaction (ERC-2771) context.
     * @return The message calldata.
     */
    function _msgData() internal view virtual override(RuleWhitelistWrapperBase, Context) returns (bytes calldata) {
        return RuleWhitelistWrapperBase._msgData();
    }

    /**
     * @notice Returns the length of the context suffix appended by the forwarder.
     * @return The context suffix length in bytes.
     */
    function _contextSuffixLength()
        internal
        view
        virtual
        override(RuleWhitelistWrapperBase, Context)
        returns (uint256)
    {
        return RuleWhitelistWrapperBase._contextSuffixLength();
    }
}
