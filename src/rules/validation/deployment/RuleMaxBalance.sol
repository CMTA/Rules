// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleMaxBalanceBase} from "../abstract/base/RuleMaxBalanceBase.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";

/**
 * @title RuleMaxBalance
 * @notice Caps how many tokens a single address may hold, with an operator-managed exemption list.
 * @dev WARNING: pair this with a rule that admits one address per investor (`RuleWhitelist`,
 * `RuleReceiverWhitelist` or `RuleIdentityRegistry`). The cap counts tokens per address, so a holder
 * with several addresses can otherwise exceed it.
 */
contract RuleMaxBalance is AccessControlModuleStandalone, RuleMaxBalanceBase {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     * @param balanceToken_ Token contract that exposes `balanceOf` (must be a contract).
     * @param maxBalance_ Initial maximum balance per non-exempt address.
     */
    constructor(address admin, address balanceToken_, uint256 maxBalance_)
        AccessControlModuleStandalone(admin)
        RuleMaxBalanceBase(balanceToken_, maxBalance_)
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
     * @notice Restricts cap, token and exemption management to MAX_BALANCE_ROLE.
     */
    function _authorizeMaxBalanceManager() internal view virtual override onlyRole(MAX_BALANCE_ROLE) {}
}
