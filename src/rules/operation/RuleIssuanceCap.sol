// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC3643ComplianceRolesStorage} from "RuleEngine/modules/library/ERC3643ComplianceRolesStorage.sol";
import {AccessControlModuleStandalone} from "../../modules/AccessControlModuleStandalone.sol";
import {RuleTransferValidation} from "../validation/abstract/core/RuleTransferValidation.sol";
import {RuleIssuanceCapBase} from "./abstract/RuleIssuanceCapBase.sol";

/**
 * @title RuleIssuanceCap
 * @notice Non-replenishing issuance cap, AccessControl variant.
 *         `MAX_TOTAL_SUPPLY_ROLE` changes the cap; `COMPLIANCE_MANAGER_ROLE` binds the caller (token or
 *         RuleEngine); `DEFAULT_ADMIN_ROLE` implicitly holds all roles.
 */
contract RuleIssuanceCap is AccessControlModuleStandalone, RuleIssuanceCapBase, ERC3643ComplianceRolesStorage {
    /**
     * @notice Role allowed to change the cap (`setMaxTotalSupply`, `increaseMaxTotalSupply`, `decreaseMaxTotalSupply`).
     */
    bytes32 public constant MAX_TOTAL_SUPPLY_ROLE = keccak256("MAX_TOTAL_SUPPLY_ROLE");

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     * @param tokenContract_ Token whose mints are capped; fixed for the life of the rule.
     * @param issuanceCap_ Maximum cumulative issuance, in token base units (scaled by `10 ** decimals()`).
     * @param initialIssued_ Issuance before the rule was installed; at least the token's current supply.
     */
    constructor(address admin, address tokenContract_, uint256 issuanceCap_, uint256 initialIssued_)
        AccessControlModuleStandalone(admin)
        RuleIssuanceCapBase(tokenContract_, issuanceCap_, initialIssued_)
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
     * @notice Restricts cap management to MAX_TOTAL_SUPPLY_ROLE.
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual override onlyRole(MAX_TOTAL_SUPPLY_ROLE) {}

    /**
     * @notice Restricts binding management to COMPLIANCE_MANAGER_ROLE.
     */
    function _onlyComplianceManager() internal view virtual override onlyRole(COMPLIANCE_MANAGER_ROLE) {}

    /**
     * @notice Restricts bind / unbind to COMPLIANCE_MANAGER_ROLE.
     */
    function _authorizeTokenBindingChange(address) internal view virtual override onlyRole(COMPLIANCE_MANAGER_ROLE) {}
}
