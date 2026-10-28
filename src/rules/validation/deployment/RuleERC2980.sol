// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
/* ==== Abstract contracts === */
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleERC2980Base} from "../abstract/base/RuleERC2980Base.sol";

/**
 * @title RuleERC2980
 * @notice ERC-2980 Swiss Compliant transfer rule combining a whitelist and a frozenlist.
 * @dev Whitelist: only whitelisted addresses may **receive**; senders need not be listed.
 * Frozenlist: frozen addresses may neither send nor receive, and it takes priority over the
 * whitelist. Codes 60 (sender frozen), 61 (recipient frozen), 62 (spender frozen), 63 (recipient not
 * whitelisted).
 *
 * @dev Access control via {AccessControlModuleStandalone}: `WHITELIST_ADD_ROLE`,
 * `WHITELIST_REMOVE_ROLE`, `FROZENLIST_ADD_ROLE`, `FROZENLIST_REMOVE_ROLE`, with
 * `DEFAULT_ADMIN_ROLE` implicitly holding all of them.
 */
contract RuleERC2980 is RuleERC2980Base, AccessControlModuleStandalone {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives `DEFAULT_ADMIN_ROLE` (implicitly holds all roles).
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder for meta-transactions.
     * @param allowMintBurn When true, permits both minting and burning (sets `allowMint` and `allowBurn`).
     */
    constructor(address admin, address forwarderIrrevocable, bool allowMintBurn)
        RuleERC2980Base(forwarderIrrevocable, allowMintBurn)
        AccessControlModuleStandalone(admin)
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
        override(AccessControlEnumerable, RuleERC2980Base)
        returns (bool)
    {
        return AccessControlEnumerable.supportsInterface(interfaceId) || RuleERC2980Base.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts toggling `allowMint` / `allowBurn` to holders of DEFAULT_ADMIN_ROLE.
     */
    function _authorizeMintBurnManager() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Restricts adding addresses to the whitelist to holders of WHITELIST_ADD_ROLE.
     */
    function _authorizeWhitelistAdd() internal view virtual override onlyRole(WHITELIST_ADD_ROLE) {}

    /**
     * @notice Restricts removing addresses from the whitelist to holders of WHITELIST_REMOVE_ROLE.
     */
    function _authorizeWhitelistRemove() internal view virtual override onlyRole(WHITELIST_REMOVE_ROLE) {}

    /**
     * @notice Restricts adding addresses to the frozenlist to holders of FROZENLIST_ADD_ROLE.
     */
    function _authorizeFrozenlistAdd() internal view virtual override onlyRole(FROZENLIST_ADD_ROLE) {}

    /**
     * @notice Restricts removing addresses from the frozenlist to holders of FROZENLIST_REMOVE_ROLE.
     */
    function _authorizeFrozenlistRemove() internal view virtual override onlyRole(FROZENLIST_REMOVE_ROLE) {}

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
