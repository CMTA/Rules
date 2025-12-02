//SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {AccessControl} from "OZ/access/AccessControl.sol";

abstract contract AccessControlModuleStandalone is AccessControl {
    error AccessControlModuleStandalone_AddressZeroNotAllowed();
    /* ============ Constructor ============ */
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
    constructor(address admin)
    {
        if(admin == address(0)){
            revert AccessControlModuleStandalone_AddressZeroNotAllowed();
        }
        // we don't check the return value
        // _grantRole attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
        // return false only if the admin has already the role
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }


    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /** 
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override(AccessControl) returns (bool) {
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        } else {
            return AccessControl.hasRole(role, account);
        }
    }
}
