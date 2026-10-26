// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

/* ==== CMTAT === */
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643ComplianceRead, IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IRuleEngine, IRuleEngineERC1404} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== RuleEngine === */
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
/* ==== CMTAT libraries === */
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
/* ==== Modules === */
import {VersionModule} from "../../../../modules/VersionModule.sol";

/**
 * @title RuleTransferValidation — base transfer-restriction checks and interface support for rules.
 * @notice Exposes ERC-1404 / ERC-3643 / ERC-7551 read views delegating to internal restriction hooks.
 */
abstract contract RuleTransferValidation is
    VersionModule,
    IERC1404Extend,
    IERC3643ComplianceRead,
    IERC7551Compliance,
    IRuleEngineERC1404,
    IRule
{
    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC1404
     */
    function detectTransferRestriction(address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC1404)
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
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
        return _detectTransferRestrictionFrom(spender, from, to, value);
    }

    /**
     * @notice Validate a transfer
     * @param from the origin address
     * @param to the destination address
     * @param amount to transfer
     * @return isValid => true if the transfer is valid, false otherwise
     *
     */
    function canTransfer(address from, address to, uint256 amount)
        public
        view
        virtual
        override(IERC3643ComplianceRead)
        returns (bool isValid)
    {
        return _detectTransferRestriction(from, to, amount) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7551Compliance
     */
    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC7551Compliance)
        returns (bool)
    {
        return _detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    // Declared here because `IRule` and CMTAT's `IRuleEngine` both declare it and are unrelated since
    // RuleEngine v3.0.0-rc7; each rule implements it.
    /**
     * @notice Applies the rule to an operation that carries a spender: `transferFrom`, and mint / burn since
     * CMTAT v3.3, with the operator as `spender`. Reverts if the operation is not allowed.
     * @param spender The account that initiated the operation.
     * @param from The origin address, zero on a mint.
     * @param to The destination address, zero on a burn.
     * @param value The number of tokens involved.
     */
    function transferred(address spender, address from, address to, uint256 value)
        public
        virtual
        override(IRule, IRuleEngine);

    /**
     * @notice Returns whether this contract implements the given interface.
     * @param interfaceId The ERC-165 interface identifier to query.
     * @return True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID
            || interfaceId == ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_LEGACY_INTERFACE_ID
            || interfaceId == type(IERC7551Compliance).interfaceId
            || interfaceId == type(IERC3643IComplianceContract).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal transfer restriction check.
     * @param from the origin address
     * @param to the destination address
     * @param value amount to transfer
     * @return restrictionCode The restriction code for this rule.
     */
    function _detectTransferRestriction(address from, address to, uint256 value)
        internal
        view
        virtual
        returns (uint8 restrictionCode);

    /**
     * @notice Internal transfer restriction check for spender-initiated transfers.
     * @param spender the caller executing the transfer
     * @param from the origin address
     * @param to the destination address
     * @param value amount to transfer
     * @return restrictionCode The restriction code for this rule.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        returns (uint8 restrictionCode);
}
