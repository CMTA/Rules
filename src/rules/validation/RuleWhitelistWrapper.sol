// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {AccessControl} from "OZ/access/AccessControl.sol";
/* ==== Abtract contracts === */
import {AccessControlModuleStandalone} from "../../modules/AccessControlModuleStandalone.sol";
import {MetaTxModuleStandalone, ERC2771Context, Context} from "../../modules/MetaTxModuleStandalone.sol";
import {RuleAddressSet} from "./abstract/RuleAddressSet/RuleAddressSet.sol";
import {RuleWhitelistCommon} from "./abstract/RuleWhitelistCommon.sol";
/* ==== RuleEngine === */
import {RulesManagementModule} from "RuleEngine/modules/RulesManagementModule.sol";
import {RuleEngineInvariantStorage} from "RuleEngine/modules/library/RuleEngineInvariantStorage.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
/* ==== CMTAT === */
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
/* ==== Interfaces === */
import {IERC7943NonFungibleCompliance, IERC7943NonFungibleComplianceExtend} from "../interfaces/IERC7943NonFungibleCompliance.sol";

/**
 * @title Wrapper to call several different whitelist rules
 */
contract RuleWhitelistWrapper is RulesManagementModule, AccessControlModuleStandalone, MetaTxModuleStandalone, RuleWhitelistCommon {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    constructor(address admin, address forwarderIrrevocable, bool checkSpender_)
        MetaTxModuleStandalone(forwarderIrrevocable) AccessControlModuleStandalone(admin)
    {
        checkSpender = checkSpender_;
    }

    /**
     * @notice Go through all the whitelist rules to know if a restriction exists on the transfer
     * @param from the origin address
     * @param to the destination address
     * @return The restricion code or REJECTED_CODE_BASE.TRANSFER_OK
     *
     */
    function detectTransferRestriction(address from, address to, uint256 /*value*/ )
        public
        view
        override(IERC1404)
        returns (uint8)
    {
        address[] memory targetAddress = new address[](2);
        targetAddress[0] = from;
        targetAddress[1] = to;

        bool[] memory result = _detectTransferRestriction(targetAddress);
        if (!result[0]) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!result[1]) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    function detectTransferRestriction(address from, address to, uint256 /* tokenId */, uint256 value )
        public
        view
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return detectTransferRestriction(from, to, value);
    }

    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        public
        view
        override(IERC1404Extend)
        returns (uint8)
    {
        if (!checkSpender) {
            return detectTransferRestriction(from, to, value);
        }

        address[] memory targetAddress = new address[](2);
        targetAddress[0] = from;
        targetAddress[1] = to;
        targetAddress[2] = spender;

        bool[] memory result = _detectTransferRestriction(targetAddress);

        if (!result[0]) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!result[1]) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        } else if (!result[2]) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    /**
    * @inheritdoc IERC7943NonFungibleComplianceExtend
    */
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 /* tokenId */, uint256 value )
        public
        view
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return detectTransferRestrictionFrom(spender, from, to, value);
    }


    /* ============  Access control ============ */

     /** 
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override(AccessControl,AccessControlModuleStandalone ) returns (bool) {
       return AccessControlModuleStandalone.hasRole(role, account);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _detectTransferRestriction(address[] memory targetAddress) internal view returns (bool[] memory) {
        uint256 rulesLength = rulesCount();
        bool[] memory result = new bool[](targetAddress.length);
        for (uint256 i = 0; i < rulesLength; ++i) {
            // Call the whitelist rules
            bool[] memory isListed = RuleAddressSet(rule(i)).areAddressesListed(targetAddress);
            for (uint256 j = 0; j < targetAddress.length; ++j) {
                if (isListed[j]) {
                    result[j] = true;
                }
            }

            // Break early if all listed
            bool allListed = true;
            for (uint256 k = 0; k < result.length; ++k) {
                if (!result[k]) {
                    allListed = false;
                    break;
                }
            }
            if (allListed) {
                break;
            }
        }
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC-2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
