// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {RuleReceiverWhitelistBase} from "../abstract/base/RuleReceiverWhitelistBase.sol";
import {RuleAddressSet} from "../abstract/RuleAddressSet/RuleAddressSet.sol";

/**
 * @title RuleReceiverWhitelist
 * @notice AccessControlEnumerable deployment variant of receiver whitelist rule.
 */
contract RuleReceiverWhitelist is RuleReceiverWhitelistBase, AccessControlModuleStandalone {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the rule, sets the admin and the meta-transaction forwarder.
     * @param admin Address that receives the default admin role.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder for meta-transactions.
     */
    constructor(address admin, address forwarderIrrevocable)
        RuleReceiverWhitelistBase(forwarderIrrevocable)
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
        override(AccessControlEnumerable, RuleReceiverWhitelistBase)
        returns (bool)
    {
        return AccessControlEnumerable.supportsInterface(interfaceId)
            || RuleReceiverWhitelistBase.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts adding addresses to the receiver whitelist to holders of ADDRESS_LIST_ADD_ROLE.
     */
    function _authorizeAddressListAdd() internal view virtual override onlyRole(ADDRESS_LIST_ADD_ROLE) {}

    /**
     * @notice Restricts removing addresses from the receiver whitelist to holders of ADDRESS_LIST_REMOVE_ROLE.
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
