// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
/* ==== Abstract contracts === */
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleWhitelistBase} from "../abstract/base/RuleWhitelistBase.sol";
import {RuleAddressSet} from "../abstract/RuleAddressSet/RuleAddressSet.sol";

/* ==== CMTAT === */

/**
 * @title Rule Whitelist
 * @notice Manages a whitelist of authorized addresses and enforces whitelist-based transfer restrictions.
 * @dev
 * - Inherits core address management logic from {RuleAddressSet}.
 * - Integrates restriction code logic from {RuleWhitelistShared}.
 * - Implements {IERC1404} to return specific restriction codes for non-whitelisted transfers.
 */
contract RuleWhitelist is RuleWhitelistBase, AccessControlModuleStandalone {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     * @param checkSpender_ Enables spender checks for transferFrom when true.
     * @param allowMintBurn When true, permits both minting and burning (sets `allowMint` and `allowBurn`).
     */
    constructor(address admin, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistBase(forwarderIrrevocable, checkSpender_, allowMintBurn)
        AccessControlModuleStandalone(admin)
    {
        // no-op
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Indicates whether this contract supports a given interface.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return supported True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, RuleWhitelistBase)
        returns (bool)
    {
        return AccessControlEnumerable.supportsInterface(interfaceId)
            || RuleWhitelistBase.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts toggling the spender-check setting to holders of DEFAULT_ADMIN_ROLE.
     */
    function _authorizeCheckSpenderManager() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Restricts toggling `allowMint` / `allowBurn` to holders of DEFAULT_ADMIN_ROLE.
     */
    function _authorizeMintBurnManager() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Restricts adding addresses to the whitelist to holders of ADDRESS_LIST_ADD_ROLE.
     */
    function _authorizeAddressListAdd() internal view virtual override onlyRole(ADDRESS_LIST_ADD_ROLE) {}

    /**
     * @notice Restricts removing addresses from the whitelist to holders of ADDRESS_LIST_REMOVE_ROLE.
     */
    function _authorizeAddressListRemove() internal view virtual override onlyRole(ADDRESS_LIST_REMOVE_ROLE) {}

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
