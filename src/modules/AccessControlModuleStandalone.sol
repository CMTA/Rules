//SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/* ==== OpenZeppelin === */
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/**
 * @title AccessControlModuleStandalone — base RBAC module where the default admin implicitly holds all roles.
 */
abstract contract AccessControlModuleStandalone is AccessControlEnumerable {
    error AccessControlModuleStandalone_AddressZeroNotAllowed();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Assigns the provided address as the default admin.
     * @dev
     *  - Reverts if `admin` is the zero address.
     *  - Grants `DEFAULT_ADMIN_ROLE` to `admin`.
     *    The return value of `_grantRole` is intentionally ignored, as it returns `false`
     *    only when the role was already granted.
     *
     * @param admin The address that will receive the `DEFAULT_ADMIN_ROLE`.
     */
    constructor(address admin) {
        require(admin != address(0), AccessControlModuleStandalone_AddressZeroNotAllowed());
        // we don't check the return value
        // _grantRole attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
        // return false only if the admin has already the role
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IAccessControl
     * @dev The default admin is treated as holding every role.
     */
    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override(AccessControl, IAccessControl)
        returns (bool)
    {
        // Dev note: default admin is treated as having all roles but may not appear in enumerable role members.
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        } else {
            return AccessControl.hasRole(role, account);
        }
    }
}
