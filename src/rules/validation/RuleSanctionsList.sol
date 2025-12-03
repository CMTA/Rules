// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import {AccessControl} from "OZ/access/AccessControl.sol";
/* ==== Abtract contracts === */
import {MetaTxModuleStandalone, ERC2771Context, Context} from "../../modules/MetaTxModuleStandalone.sol";
import {AccessControlModuleStandalone} from "../../modules/AccessControlModuleStandalone.sol";
import {RuleSanctionsListInvariantStorage} from "./abstract/RuleSanctionsListInvariantStorage.sol";
import {RuleValidateTransfer, RuleValidateTransfer} from "./abstract/RuleValidateTransfer.sol";
/* ==== Interfaces === */
import {ISanctionsList} from "../interfaces/ISanctionsList.sol";
import {IERC7943NonFungibleComplianceExtend} from "../interfaces/IERC7943NonFungibleCompliance.sol";
/* ==== CMTAT === */
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== IRuleEngine === */
import {IRule} from "RuleEngine/interfaces/IRule.sol";


/**
 * @title RuleSanctionsList
 * @notice Compliance rule enforcing sanctions-screening for token transfers.
 * @dev
 *  This rule integrates a sanctions-oracle (e.g., Chainalysis) and blocks
 *  transfers when:
 *    - the sender is sanctioned,
 *    - the recipient is sanctioned,
 *    - or the spender/operator is sanctioned.
 *
 *  Features:
 *    - Supports ERC-1404, ERC-3643 (transferred) and ERC-7943 non-fungible compliance flows.
 *    - Oracle address can be updated by accounts holding `SANCTIONLIST_ROLE`.
 *    - Zero oracle address disables sanctions checks (all transfers allowed).
 *
 *  The rule is designed for RuleEngine or for direct integration with
 *  CMTAT / ERC-3643 compliant tokens.
 */
contract RuleSanctionsList is
    AccessControlModuleStandalone,
    MetaTxModuleStandalone,
    RuleValidateTransfer,
    RuleSanctionsListInvariantStorage
{
    ISanctionsList public sanctionsList;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param admin Address of the contract (Access Control)
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    constructor(address admin, address forwarderIrrevocable, ISanctionsList sanctionContractOracle_)
        MetaTxModuleStandalone(forwarderIrrevocable)
        AccessControlModuleStandalone(admin)
    {
        if (address(sanctionContractOracle_) != address(0)) {
            _setSanctionListOracle(sanctionContractOracle_);
        }
    }

    /* ============  View Functions ============ */

    /**
     * @notice Check if an addres is in the SanctionsList or not
     * @param from the origin address
     * @param to the destination address
     * @return The restricion code or REJECTED_CODE_BASE.TRANSFER_OK
     *
     */
    function detectTransferRestriction(address from, address to, uint256 /*value */ )
        public
        view
        override(IERC1404)
        returns (uint8)
    {
        if (address(sanctionsList) != address(0)) {
            if (sanctionsList.isSanctioned(from)) {
                return CODE_ADDRESS_FROM_IS_SANCTIONED;
            } else if (sanctionsList.isSanctioned(to)) {
                return CODE_ADDRESS_TO_IS_SANCTIONED;
            }
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestriction(address from, address to, uint256, /* tokenId */ uint256 value)
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc IERC1404Extend
     */
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC1404Extend)
        returns (uint8)
    {
        if (address(sanctionsList) != address(0)) {
            if (sanctionsList.isSanctioned(spender)) {
                return CODE_ADDRESS_SPENDER_IS_SANCTIONED;
            } else {
                return detectTransferRestriction(from, to, value);
            }
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function detectTransferRestrictionFrom(
        address spender,
        address from,
        address to,
        uint256, /* tokenId */
        uint256 value
    ) public view virtual override(IERC7943NonFungibleComplianceExtend) returns (uint8) {
        return detectTransferRestrictionFrom(spender, from, to, value);
    }

    /**
     * @notice To know if the restriction code is valid for this rule or not.
     * @param restrictionCode The target restriction code
     * @return true if the restriction code is known, false otherwise
     *
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_ADDRESS_FROM_IS_SANCTIONED || restrictionCode == CODE_ADDRESS_TO_IS_SANCTIONED
            || restrictionCode == CODE_ADDRESS_SPENDER_IS_SANCTIONED;
    }

    /**
     * @notice Return the corresponding message
     * @param restrictionCode The target restriction code
     * @return true if the transfer is valid, false otherwise
     *
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        virtual
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_IS_SANCTIONED) {
            return TEXT_ADDRESS_FROM_IS_SANCTIONED;
        } else if (restrictionCode == CODE_ADDRESS_TO_IS_SANCTIONED) {
            return TEXT_ADDRESS_TO_IS_SANCTIONED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_IS_SANCTIONED) {
            return TEXT_ADDRESS_SPENDER_IS_SANCTIONED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, RuleValidateTransfer) returns (bool) {
        return AccessControl.supportsInterface(interfaceId) || RuleValidateTransfer.supportsInterface(interfaceId);
    }

    /* ============  State Functions ============ */
    /**
     * @notice Set the oracle contract
     * @param sanctionContractOracle_ address of your oracle contract
     * @dev zero address is authorized to authorize all transfers
     */
    function setSanctionListOracle(ISanctionsList sanctionContractOracle_) public virtual onlyRole(SANCTIONLIST_ROLE) {
        _setSanctionListOracle(sanctionContractOracle_);
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC3643IComplianceContract)
    {
        uint8 code = this.detectTransferRestriction(from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSanctionsList_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IRuleEngine)
    {
        uint8 code = this.detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSanctionsList_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function transferred(address spender, address from, address to, uint256, /* tokenId */ uint256 value)
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
    {
        transferred(spender, from, to, value);
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
