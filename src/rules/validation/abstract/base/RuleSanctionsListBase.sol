// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {MetaTxModuleStandalone} from "../../../../modules/MetaTxModuleStandalone.sol";
import {RuleSanctionsListInvariantStorage} from "../invariant/RuleSanctionsListInvariantStorage.sol";
import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {ISanctionsList} from "../../../interfaces/ISanctionsList.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

/**
 * @title RuleSanctionsListBase
 * @notice Compliance rule enforcing sanctions-screening for token transfers.
 */
abstract contract RuleSanctionsListBase is MetaTxModuleStandalone, RuleNFTAdapter, RuleSanctionsListInvariantStorage {
    /**
     * @notice The sanctions oracle consulted on each transfer; unset disables screening.
     */
    ISanctionsList public sanctionsList;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the sanctions-list rule base and optionally sets the oracle.
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address for meta-transactions.
     * @param sanctionContractOracle_ Initial sanctions oracle; skipped when the zero address.
     */
    constructor(address forwarderIrrevocable, ISanctionsList sanctionContractOracle_)
        MetaTxModuleStandalone(forwarderIrrevocable)
    {
        if (address(sanctionContractOracle_) != address(0)) {
            _setSanctionListOracle(sanctionContractOracle_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IRule
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_ADDRESS_FROM_IS_SANCTIONED || restrictionCode == CODE_ADDRESS_TO_IS_SANCTIONED
            || restrictionCode == CODE_ADDRESS_SPENDER_IS_SANCTIONED;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the sanctions oracle consulted on each transfer.
     * @dev Restricted to the sanction-list manager; reverts on the zero address.
     * @param sanctionContractOracle_ The new sanctions oracle address.
     */
    function setSanctionListOracle(ISanctionsList sanctionContractOracle_) public virtual onlySanctionListManager {
        require(address(sanctionContractOracle_) != address(0), RuleSanctionsList_OracleAddressZeroNotAllowed());
        _setSanctionListOracle(sanctionContractOracle_);
    }

    /**
     * @notice Clears the sanctions oracle, disabling sanctions screening.
     * @dev Restricted to the sanction-list manager.
     */
    function clearSanctionListOracle() public virtual onlySanctionListManager {
        _setSanctionListOracle(ISanctionsList(address(0)));
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRule
     */
    function transferred(address spender, address from, address to, uint256 value) public view override {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_IS_SANCTIONED) {
            return TEXT_ADDRESS_FROM_IS_SANCTIONED;
        } else if (restrictionCode == CODE_ADDRESS_TO_IS_SANCTIONED) {
            return TEXT_ADDRESS_TO_IS_SANCTIONED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_IS_SANCTIONED) {
            return TEXT_ADDRESS_SPENDER_IS_SANCTIONED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlySanctionListManager() {
        _authorizeSanctionListManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the stored sanctions oracle and emits {SetSanctionListOracle}.
     * @param sanctionContractOracle_ The new sanctions oracle address (may be zero to disable).
     */
    function _setSanctionListOracle(ISanctionsList sanctionContractOracle_) internal virtual {
        sanctionsList = sanctionContractOracle_;
        emit SetSanctionListOracle(sanctionContractOracle_);
    }

    /**
     * @notice Authorizes the caller as sanction-list manager; reverts otherwise.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeSanctionListManager() internal view virtual;

    /**
     * @notice Detects whether a direct transfer is restricted by the sanctions oracle.
     * @dev The zero address is the ERC-20 mint/burn sentinel, not a participant, so it is never sent
     *      to the oracle: on a mint `from` is skipped, on a burn `to` is skipped. Asking a
     *      third-party contract whether `address(0)` is sanctioned would delegate this rule's
     *      mint/burn behaviour to that contract's handling of a degenerate input -- an oracle
     *      answering `true` would block ALL issuance and ALL redemption, trapping holders. Every
     *      other rule in this library screens only the real participants for the same reason.
     * @param from The sender address; the zero address denotes a mint and is not screened.
     * @param to The recipient address; the zero address denotes a burn and is not screened.
     * @return The restriction code, or TRANSFER_OK when no party is sanctioned.
     */
    function _detectTransferRestriction(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Read the oracle address once. Safe to cache across the calls below: this function is
        // `view`, so those are STATICCALLs and cannot write `sanctionsList`.
        ISanctionsList oracle = sanctionsList;
        if (address(oracle) != address(0)) {
            if (from != address(0) && oracle.isSanctioned(from)) {
                return CODE_ADDRESS_FROM_IS_SANCTIONED;
            } else if (to != address(0) && oracle.isSanctioned(to)) {
                return CODE_ADDRESS_TO_IS_SANCTIONED;
            }
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects whether a delegated transfer is restricted by the sanctions oracle.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     * @return The restriction code, or TRANSFER_OK when no party is sanctioned.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        ISanctionsList oracle = sanctionsList;
        // The oracle guard scopes ONLY the spender check; the delegation below is unconditional, as
        // in every sibling rule. Nesting the delegation inside the guard -- as this function used to
        // -- silently drops any check in {_detectTransferRestriction} that does not depend on the
        // oracle, including one added by a subclass overriding that hook.
        if (address(oracle) != address(0) && oracle.isSanctioned(spender)) {
            return CODE_ADDRESS_SPENDER_IS_SANCTIONED;
        }
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Reverts if a direct transfer is blocked by the sanctions oracle.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSanctionsList_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Reverts if a delegated transfer is blocked by the sanctions oracle.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSanctionsList_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
