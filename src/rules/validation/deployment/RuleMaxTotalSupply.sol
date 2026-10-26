// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleMaxTotalSupplyBase} from "../abstract/base/RuleMaxTotalSupplyBase.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";

/**
 * @title RuleMaxTotalSupply
 * @notice Restricts minting so that total supply never exceeds a maximum value.
 */
contract RuleMaxTotalSupply is AccessControlModuleStandalone, RuleMaxTotalSupplyBase {
    /**
     * @notice Role allowed to change the cap (`setMaxTotalSupply`, `increaseMaxTotalSupply`,
     * `decreaseMaxTotalSupply`). Repointing the token stays with
     * `DEFAULT_ADMIN_ROLE`, which also implicitly holds this role.
     * @dev Declared here, not in the invariant storage, so the Ownable2Step variant does not publish a
     * role it never checks.
     */
    bytes32 public constant MAX_TOTAL_SUPPLY_ROLE = keccak256("MAX_TOTAL_SUPPLY_ROLE");

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param maxTotalSupply_ Initial maximum supply, in token base units (scaled by `10 ** decimals()`).
     */
    constructor(address admin, address tokenContract_, uint256 maxTotalSupply_)
        AccessControlModuleStandalone(admin)
        RuleMaxTotalSupplyBase(tokenContract_, maxTotalSupply_)
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
     * @notice Restricts cap management to MAX_TOTAL_SUPPLY_ROLE (the admin holds it implicitly).
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual override onlyRole(MAX_TOTAL_SUPPLY_ROLE) {}

    /**
     * @notice Restricts repointing the observed token to DEFAULT_ADMIN_ROLE.
     */
    function _authorizeTokenContractManager() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
