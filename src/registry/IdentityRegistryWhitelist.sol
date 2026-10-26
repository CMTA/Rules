// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlModuleStandalone} from "../modules/AccessControlModuleStandalone.sol";
import {IdentityRegistryWhitelistBase} from "./abstract/IdentityRegistryWhitelistBase.sol";

/**
 * @title IdentityRegistryWhitelist
 * @notice A whitelist that plugs directly into an ERC-3643 token as its identity registry.
 * @dev Install with `token.setIdentityRegistry(address(this))`. Grant {IDENTITY_REGISTRAR_ROLE} to
 * the operator that maintains the whitelist **and to the token itself**, otherwise
 * `recoveryAddress` reverts -- see the technical doc.
 *
 * This is not a compliance rule: it implements no `IRule` surface and must not be added to a
 * `RuleEngine`.
 */
contract IdentityRegistryWhitelist is AccessControlModuleStandalone, IdentityRegistryWhitelistBase {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     */
    constructor(address admin) AccessControlModuleStandalone(admin) {}

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts identity registration and deletion to IDENTITY_REGISTRAR_ROLE.
     */
    function _authorizeIdentityRegistrar() internal view virtual override onlyRole(IDENTITY_REGISTRAR_ROLE) {}
}
