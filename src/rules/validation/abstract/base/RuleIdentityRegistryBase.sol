// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleIdentityRegistryInvariantStorage} from "../invariant/RuleIdentityRegistryInvariantStorage.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";

/**
 * @title RuleIdentityRegistryBase
 * @notice Checks the ERC-3643 Identity Registry for transfer participants when configured.
 * @dev **ERC-3643 conformant by default: only the RECEIVER is verified.** The spec states the
 *      receiver must be whitelisted and verified, that `transferFrom` works the same way, that
 *      `mint` and `forcedTransfer` require only the receiver, and that `burn` bypasses eligibility.
 *
 *      The sender, spender and minter are NOT required to be verified. Checking the sender would
 *      TRAP DE-LISTED HOLDERS: the spec screens only the receiver precisely so an investor whose
 *      identity lapses can still exit to a verified counterparty. Stricter screening is available as
 *      an explicit opt-in ({checkSender}, {checkSpender}), not an undocumented default.
 */
abstract contract RuleIdentityRegistryBase is RuleNFTAdapter, RuleIdentityRegistryInvariantStorage {
    /**
     * @notice The ERC-3643 Identity Registry consulted to verify transfer participants; the zero address disables checks.
     */
    IIdentityRegistryVerified public identityRegistry;

    /**
     * @notice When true, ALSO require the sender to be identity-verified.
     * @dev Defaults to FALSE: ERC-3643 does not require it. Enabling it is stricter than the
     *      specification and prevents a de-listed holder from exiting their position.
     */
    bool public checkSender;

    /**
     * @notice When true, ALSO require the spender to be identity-verified on `transferFrom`.
     * @dev Defaults to FALSE: ERC-3643 does not require it ("`transferFrom` works the same way").
     *      Mint and burn are exempt from this check regardless — the minter/burner acts on its own
     *      authority, not as a delegated ERC-20 spender.
     */
    bool public checkSpender;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with an optional identity registry.
     * @dev Pass `false, false` for the ERC-3643-conformant default (only the receiver is verified).
     * @param identityRegistry_ Identity registry address; when the zero address, the registry is left unset (checks disabled).
     * @param checkSender_ When true, also verify the sender (STRICTER than ERC-3643).
     * @param checkSpender_ When true, also verify the spender on `transferFrom` (STRICTER than ERC-3643).
     */
    constructor(address identityRegistry_, bool checkSender_, bool checkSpender_) {
        // Every value actually assigned here is announced, so the deployed configuration can be
        // reconstructed from events alone. The registry is only assigned when non-zero -- a zero
        // argument leaves the default untouched, so there is nothing to report, matching
        // {RuleSanctionsListBase}'s constructor.
        if (identityRegistry_ != address(0)) {
            identityRegistry = IIdentityRegistryVerified(identityRegistry_);
            emit IdentityRegistryUpdated(identityRegistry_);
        }
        checkSender = checkSender_;
        checkSpender = checkSpender_;
        emit IdentityCheckSenderUpdated(checkSender_);
        emit IdentityCheckSpenderUpdated(checkSpender_);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyIdentityRegistryManager() {
        _authorizeIdentityRegistryManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is one of this rule's identity-verification codes.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_ADDRESS_FROM_NOT_VERIFIED || restrictionCode == CODE_ADDRESS_TO_NOT_VERIFIED
            || restrictionCode == CODE_ADDRESS_SPENDER_NOT_VERIFIED;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the identity registry consulted during transfer checks.
     * @param newRegistry New identity registry address; must not be the zero address.
     */
    function setIdentityRegistry(address newRegistry) public virtual onlyIdentityRegistryManager {
        require(newRegistry != address(0), RuleIdentityRegistry_RegistryAddressZeroNotAllowed());
        identityRegistry = IIdentityRegistryVerified(newRegistry);
        emit IdentityRegistryUpdated(newRegistry);
    }

    /**
     * @notice Enables or disables the (non-ERC-3643) sender verification check.
     * @dev STRICTER than ERC-3643, which verifies only the receiver. Enabling this prevents a
     *      de-listed holder from exiting their position.
     * @param value The new value of the `checkSender` flag.
     */
    function setCheckSender(bool value) public virtual onlyIdentityRegistryManager {
        checkSender = value;
        emit IdentityCheckSenderUpdated(value);
    }

    /**
     * @notice Enables or disables the (non-ERC-3643) spender verification check on `transferFrom`.
     * @dev STRICTER than ERC-3643. Mint and burn remain exempt regardless.
     * @param value The new value of the `checkSpender` flag.
     */
    function setCheckSpender(bool value) public virtual onlyIdentityRegistryManager {
        checkSpender = value;
        emit IdentityCheckSpenderUpdated(value);
    }

    /**
     * @notice Clears the identity registry, disabling identity checks (all transfers pass this rule).
     */
    function clearIdentityRegistry() public virtual onlyIdentityRegistryManager {
        identityRegistry = IIdentityRegistryVerified(address(0));
        emit IdentityRegistryUpdated(address(0));
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
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
        if (restrictionCode == CODE_ADDRESS_FROM_NOT_VERIFIED) {
            return TEXT_ADDRESS_FROM_NOT_VERIFIED;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_VERIFIED) {
            return TEXT_ADDRESS_TO_NOT_VERIFIED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_VERIFIED) {
            return TEXT_ADDRESS_SPENDER_NOT_VERIFIED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorization hook invoked before updating or clearing the identity registry.
     */
    function _authorizeIdentityRegistryManager() internal view virtual;

    /**
     * @notice Detects the restriction code for a direct transfer, verifying `from` and `to` against the registry.
     * @param from Sender address; must be verified unless it is the zero address (mint).
     * @param to Recipient address; must be verified unless it is the zero address (burn).
     * @return The applicable restriction code, or TRANSFER_OK when no restriction applies.
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
        // Read the registry address once. Safe to cache across the calls below: this function is
        // `view`, so those are STATICCALLs and cannot write `identityRegistry`.
        IIdentityRegistryVerified registry = identityRegistry;
        if (address(registry) == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        // ERC-3643: "The `burn` function bypasses all checks on eligibility."
        if (to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }

        // OPT-IN, stricter than ERC-3643. Mints carry no sender, so they are exempt.
        if (checkSender && from != address(0) && !registry.isVerified(from)) {
            return CODE_ADDRESS_FROM_NOT_VERIFIED;
        }

        // MANDATED by ERC-3643: the receiver must be verified. This is the only required check,
        // and it applies identically to `transfer`, `transferFrom` and `mint`.
        if (!registry.isVerified(to)) {
            return CODE_ADDRESS_TO_NOT_VERIFIED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects the restriction code for a `transferFrom`, verifying `spender` and delegating to the direct check.
     * @param spender Approved spender initiating the transfer; must be verified unless it is the zero address.
     * @param from Sender address, forwarded to the direct transfer check.
     * @param to Recipient address, forwarded to the direct transfer check.
     * @param value Transfer amount, forwarded to the direct transfer check.
     * @return The applicable restriction code, or TRANSFER_OK when no restriction applies.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        IIdentityRegistryVerified registry = identityRegistry;
        // The guard scopes ONLY the spender check; the delegation is unconditional, as in
        // {RuleSanctionsListBase}. Returning TRANSFER_OK here instead would silently drop any check a
        // subclass adds by overriding {_detectTransferRestriction} alone. An unset registry and a burn
        // (to == 0) both resolve to TRANSFER_OK inside the delegate, so no answer changes.
        if (address(registry) == address(0) || to == address(0)) {
            return _detectTransferRestriction(from, to, value);
        }

        // OPT-IN, stricter than ERC-3643 ("`transferFrom` works the same way" — receiver only).
        // Mint (from == 0) is exempt: the minter acts on its own authority, not as a delegated
        // ERC-20 spender. This is what makes an unverified MINTER able to mint to a verified
        // recipient, exactly as the specification requires.
        // Burn (to == 0) never reaches this line -- the guard above delegates it -- so do NOT
        // re-test `to` here; the condition would be dead.
        if (checkSpender && spender != address(0) && from != address(0) && !registry.isVerified(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_VERIFIED;
        }
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferred(address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleIdentityRegistry_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleIdentityRegistry_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
