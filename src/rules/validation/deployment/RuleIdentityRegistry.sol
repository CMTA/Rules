// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleIdentityRegistryBase} from "../abstract/base/RuleIdentityRegistryBase.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";

/**
 * @title RuleIdentityRegistry
 * @notice Checks the ERC-3643 Identity Registry for transfer participants when configured.
 * @dev Burns (to == address(0)) are allowed even if the sender is not verified.
 */
contract RuleIdentityRegistry is AccessControlModuleStandalone, RuleIdentityRegistryBase {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the admin and the ERC-3643 identity registry.
     * @dev Pass `false, false` for the ERC-3643-conformant default: the spec requires only the
     *      RECEIVER to be verified. The two flags below are stricter-than-spec opt-ins.
     * @param admin Address that receives the default admin role.
     * @param identityRegistry_ Address of the ERC-3643 identity registry to query.
     * @param checkSender_ When true, also require the sender to be verified. Stricter than
     *        ERC-3643, and it traps de-listed holders: a holder whose identity lapses can no
     *        longer exit their position. Defaults to false.
     * @param checkSpender_ When true, also require the `transferFrom` spender to be verified.
     *        Mint and burn stay exempt from this check. Defaults to false.
     */
    constructor(address admin, address identityRegistry_, bool checkSender_, bool checkSpender_)
        AccessControlModuleStandalone(admin)
        RuleIdentityRegistryBase(identityRegistry_, checkSender_, checkSpender_)
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
        override(AccessControlEnumerable, RuleTransferValidation)
        returns (bool)
    {
        return AccessControlEnumerable.supportsInterface(interfaceId)
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts identity registry management to holders of DEFAULT_ADMIN_ROLE.
     */
    function _authorizeIdentityRegistryManager() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
