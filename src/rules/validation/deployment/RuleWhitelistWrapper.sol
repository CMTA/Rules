// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/* ==== OpenZeppelin === */
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
/* ==== Abstract contracts === */
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleWhitelistWrapperBase} from "../abstract/base/RuleWhitelistWrapperBase.sol";
/* ==== RuleEngine === */
import {RulesManagementModuleRolesStorage} from "RuleEngine/modules/library/RulesManagementModuleRolesStorage.sol";

/**
 * @title Wrapper to call several different whitelist rules
 */
contract RuleWhitelistWrapper is
    RuleWhitelistWrapperBase,
    AccessControlModuleStandalone,
    RulesManagementModuleRolesStorage
{
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
        RuleWhitelistWrapperBase(forwarderIrrevocable, checkSpender_, allowMintBurn)
        AccessControlModuleStandalone(admin)
    {}

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether `account` has been granted `role`.
     * @dev Returns `true` if `account` has been granted `role`.
     * @param role Role identifier being queried.
     * @param account Address being checked for the role.
     * @return True if `account` holds `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return AccessControlModuleStandalone.hasRole(role, account);
    }

    /**
     * @notice Indicates whether this contract supports a given interface.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, RuleWhitelistWrapperBase)
        returns (bool)
    {
        return RuleWhitelistWrapperBase.supportsInterface(interfaceId)
            || AccessControlEnumerable.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Grants `role` to `account`, keeping role enumeration in sync.
     * @param role Role identifier to grant.
     * @param account Address receiving the role.
     * @return True if the role was newly granted.
     */
    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        return AccessControlEnumerable._grantRole(role, account);
    }

    /**
     * @notice Revokes `role` from `account`, keeping role enumeration in sync.
     * @param role Role identifier to revoke.
     * @param account Address losing the role.
     * @return True if the role was previously held and is now revoked.
     */
    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        return AccessControlEnumerable._revokeRole(role, account);
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
     * @notice Restricts rules management to holders of RULES_MANAGEMENT_ROLE.
     * @dev Restrict rules management to the dedicated role.
     */
    function _onlyRulesManager() internal view virtual override onlyRole(RULES_MANAGEMENT_ROLE) {}

    /**
     * @notice Restricts rules-limit management to holders of RULES_MANAGEMENT_ROLE.
     */
    function _onlyRulesLimitManager() internal view virtual override onlyRole(RULES_MANAGEMENT_ROLE) {}

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
