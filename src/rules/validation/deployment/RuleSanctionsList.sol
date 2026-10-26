// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {ERC2771Context} from "../../../modules/MetaTxModuleStandalone.sol";
import {RuleSanctionsListBase} from "../abstract/base/RuleSanctionsListBase.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";
import {ISanctionsList} from "../../interfaces/ISanctionsList.sol";

/**
 * @title RuleSanctionsList
 * @notice Compliance rule enforcing sanctions-screening for token transfers.
 */
contract RuleSanctionsList is AccessControlModuleStandalone, RuleSanctionsListBase {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     * @param sanctionContractOracle_ Chainalysis sanctions oracle used to screen addresses
     */
    constructor(address admin, address forwarderIrrevocable, ISanctionsList sanctionContractOracle_)
        AccessControlModuleStandalone(admin)
        RuleSanctionsListBase(forwarderIrrevocable, sanctionContractOracle_)
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
     * @notice Restricts sanctions list management to holders of SANCTIONLIST_ROLE.
     */
    function _authorizeSanctionListManager() internal view virtual override onlyRole(SANCTIONLIST_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the message sender, accounting for meta-transaction (ERC-2771) context.
     * @return sender The address of the message sender.
     */
    function _msgSender() internal view virtual override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @notice Returns the message calldata, accounting for meta-transaction (ERC-2771) context.
     * @return The message calldata.
     */
    function _msgData() internal view virtual override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @notice Returns the length of the context suffix appended by the forwarder.
     * @return The context suffix length in bytes.
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
