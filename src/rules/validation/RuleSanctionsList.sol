// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import {AccessControl} from "OZ/access/AccessControl.sol";
import {MetaTxModuleStandalone, ERC2771Context, Context} from "../../modules/MetaTxModuleStandalone.sol";
import {RuleSanctionsListInvariantStorage} from "./abstract/RuleSanctionsListInvariantStorage.sol";
import {RuleValidateTransfer} from "./abstract/RuleValidateTransfer.sol";
import {ISanctionsList } from "../interfaces/ISanctionsList.sol";


contract RuleSanctionsList is
    AccessControl,
    MetaTxModuleStandalone,
    RuleValidateTransfer,
    RuleSanctionsListInvariantStorage
{
    
    ISanctionsList public sanctionsList;

    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    constructor(
        address admin,
        address forwarderIrrevocable,
        ISanctionsList sanctionContractOracle_
    ) MetaTxModuleStandalone(forwarderIrrevocable) {
        if (admin == address(0)) {
            revert RuleSanctionList_AdminWithAddressZeroNotAllowed();
        }
        if (address(sanctionContractOracle_) != address(0)) {
            _setSanctionListOracle(sanctionContractOracle_);
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Set the oracle contract
     * @param sanctionContractOracle_ address of your oracle contract
     * @dev zero address is authorized to authorize all transfers
     */
    function setSanctionListOracle(
        ISanctionsList sanctionContractOracle_
    ) public onlyRole(SANCTIONLIST_ROLE) {
        _setSanctionListOracle(sanctionContractOracle_);
    }

    /**
     * @notice Check if an addres is in the SanctionsList or not
     * @param from the origin address
     * @param to the destination address
     * @return The restricion code or REJECTED_CODE_BASE.TRANSFER_OK
     **/
    function detectTransferRestriction(
        address from,
        address to,
        uint256 /*value */
    ) public view override returns (uint8) {
        if (address(sanctionsList) != address(0)) {
            if (sanctionsList.isSanctioned(from)) {
                return CODE_ADDRESS_FROM_IS_SANCTIONED;
            } else if (sanctionsList.isSanctioned(to)) {
                return CODE_ADDRESS_TO_IS_SANCTIONED;
            }
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }


    function detectTransferRestrictionFrom(
        address spender,
        address from,
        address to,
        uint256 value
    ) public view override returns (uint8) {
        if(address(sanctionsList) != address(0)){
            if (sanctionsList.isSanctioned(spender)) {
                return CODE_ADDRESS_SPENDER_IS_SANCTIONED;
            } else {
                return detectTransferRestriction(from,to,value);
            }
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice To know if the restriction code is valid for this rule or not.
     * @param _restrictionCode The target restriction code
     * @return true if the restriction code is known, false otherwise
     **/
    function canReturnTransferRestrictionCode(
        uint8 _restrictionCode
    ) external pure override returns (bool) {
        return
            _restrictionCode == CODE_ADDRESS_FROM_IS_SANCTIONED ||
            _restrictionCode == CODE_ADDRESS_TO_IS_SANCTIONED||
            _restrictionCode == CODE_ADDRESS_SPENDER_IS_SANCTIONED;
    }

    /**
     * @notice Return the corresponding message
     * @param _restrictionCode The target restriction code
     * @return true if the transfer is valid, false otherwise
     **/
    function messageForTransferRestriction(
        uint8 _restrictionCode
    ) external pure override returns (string memory) {
        if (_restrictionCode == CODE_ADDRESS_FROM_IS_SANCTIONED) {
            return TEXT_ADDRESS_FROM_IS_SANCTIONED;
        } else if (_restrictionCode == CODE_ADDRESS_TO_IS_SANCTIONED) {
            return TEXT_ADDRESS_TO_IS_SANCTIONED;
        } else if (_restrictionCode == CODE_ADDRESS_SPENDER_IS_SANCTIONED) {
            return TEXT_ADDRESS_SPENDER_IS_SANCTIONED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    function transferred(address from, address to, uint256 value) public view {
        uint8 code = this.detectTransferRestriction(from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSanctionsList_InvalidTransfer(from, to, value, code)
        );
    }

    function transferred(
        address spender,
        address from,
        address to,
        uint256 value
    ) public view {
        uint8 code = this.detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSanctionsList_InvalidTransfer(from, to, value, code)
        );
    }

    /* ============ ACCESS CONTROL ============ */
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
        } else{
            return AccessControl.hasRole(role, account);
        }
        
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setSanctionListOracle(ISanctionsList sanctionContractOracle_) internal {
        sanctionsList = sanctionContractOracle_;
        emit SetSanctionListOracle(sanctionContractOracle_);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC-2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _contextSuffixLength()
        internal
        view
        override(ERC2771Context, Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
