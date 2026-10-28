// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {MetaTxModuleStandalone, ERC2771Context} from "../../../../modules/MetaTxModuleStandalone.sol";
import {RuleERC2980Internal} from "../RuleERC2980/RuleERC2980Internal.sol";
import {RuleERC2980InvariantStorage} from "../RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";
import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
/* ==== Interfaces === */
import {IERC2980} from "../../../interfaces/IERC2980.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

/**
 * @title RuleERC2980Base
 * @notice Core ERC-2980 Swiss Compliant transfer restriction logic combining a whitelist and a frozenlist.
 * @dev
 * Transfer logic (frozenlist takes priority over whitelist):
 * 1. If `from`, `to`, or `spender` is frozen → transfer is blocked.
 * 2. If `to` is not whitelisted → transfer is blocked.
 * Note: `from` does NOT need to be whitelisted to send tokens it already holds.
 *
 * Provides public management functions for both lists with abstract authorization hooks
 * so concrete subclasses can plug in their preferred access-control mechanism.
 */
abstract contract RuleERC2980Base is
    MetaTxModuleStandalone,
    RuleERC2980InvariantStorage,
    RuleERC2980Internal,
    RuleNFTAdapter,
    IERC2980,
    IIdentityRegistryVerified
{
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Whether this rule permits minting (`from == address(0)`).
     * @dev Mint/burn permission is an EXPLICIT flag, never whitelist membership of `address(0)`.
     *      The zero address is the ERC-20 sentinel, not a participant: whitelisting it made the
     *      MANDATORY ERC-2980 getter `whitelist(address(0))` return `true`, a spec violation.
     *      A permitted mint still requires the RECIPIENT to be whitelisted and not frozen.
     */
    bool public allowMint;

    /**
     * @notice Whether this rule permits burning (`to == address(0)`).
     * @dev See {allowMint}. A permitted burn still requires the SENDER not to be frozen.
     */
    bool public allowBurn;

    /**
     * @notice Initializes the rule.
     * @dev `allowMintBurn` sets BOTH {allowMint} and {allowBurn} — the common case, since mint and
     *      burn are normally permitted. Use {setAllowMint} / {setAllowBurn} afterwards for
     *      independent control (e.g. to permanently close issuance while still allowing redemptions).
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address, set permanently at deployment.
     * @param allowMintBurn When true, permits both minting and burning.
     */
    constructor(address forwarderIrrevocable, bool allowMintBurn) MetaTxModuleStandalone(forwarderIrrevocable) {
        allowMint = allowMintBurn;
        allowBurn = allowMintBurn;
        emit AllowMintUpdated(allowMintBurn);
        emit AllowBurnUpdated(allowMintBurn);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMintBurnManager() {
        _authorizeMintBurnManager();
        _;
    }

    modifier onlyWhitelistAdd() {
        _authorizeWhitelistAdd();
        _;
    }

    modifier onlyWhitelistRemove() {
        _authorizeWhitelistRemove();
        _;
    }

    modifier onlyFrozenlistAdd() {
        _authorizeFrozenlistAdd();
        _;
    }

    modifier onlyFrozenlistRemove() {
        _authorizeFrozenlistRemove();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                       WHITELIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the whitelist.
     * @dev Does not revert if an address is already listed; duplicates are skipped. REVERTS on
     *      `address(0)`, rejecting the whole batch -- see {addWhitelistAddress}.
     * @param targetAddresses Addresses to add to the whitelist.
     */
    function addWhitelistAddresses(address[] calldata targetAddresses) public virtual onlyWhitelistAdd {
        (uint256 added, uint256 skipped) = _addWhitelistAddresses(targetAddresses);
        emit AddWhitelistAddresses(targetAddresses, added, skipped);
    }

    /**
     * @notice Removes multiple addresses from the whitelist.
     * @dev Does not revert if an address is not listed.
     * @param targetAddresses Addresses to remove from the whitelist.
     */
    function removeWhitelistAddresses(address[] calldata targetAddresses) public virtual onlyWhitelistRemove {
        (uint256 removed, uint256 skipped) = _removeWhitelistAddresses(targetAddresses);
        emit RemoveWhitelistAddresses(targetAddresses, removed, skipped);
    }

    /**
     * @notice Adds a single address to the whitelist.
     * @dev
     * Reverts if the address is already listed.
     * Deviation from ERC-2980 `Whitelistable` example interface: the spec's `addAddressToWhitelist`
     * returns `false` on duplicates instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to add to the whitelist.
     */
    function addWhitelistAddress(address targetAddress) public virtual onlyWhitelistAdd {
        require(targetAddress != address(0), RuleERC2980_ZeroAddressNotAllowed());
        require(_addWhitelistAddress(targetAddress), RuleERC2980_AddressAlreadyWhitelisted());
        emit AddWhitelistAddress(targetAddress);
    }

    /**
     * @notice Removes a single address from the whitelist.
     * @dev
     * Reverts if the address is not listed.
     * Deviation from ERC-2980 `Whitelistable` example interface: the spec's `removeAddressFromWhitelist`
     * returns `false` when not found instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to remove from the whitelist.
     */
    function removeWhitelistAddress(address targetAddress) public virtual onlyWhitelistRemove {
        require(_removeWhitelistAddress(targetAddress), RuleERC2980_AddressNotWhitelisted());
        emit RemoveWhitelistAddress(targetAddress);
    }

    /*//////////////////////////////////////////////////////////////
                      FROZENLIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the frozenlist.
     * @dev Does not revert if an address is already listed; duplicates are skipped. REVERTS on
     *      `address(0)`, rejecting the whole batch -- see {addFrozenlistAddress}.
     * @param targetAddresses Addresses to add to the frozenlist.
     */
    function addFrozenlistAddresses(address[] calldata targetAddresses) public virtual onlyFrozenlistAdd {
        (uint256 added, uint256 skipped) = _addFrozenlistAddresses(targetAddresses);
        emit AddFrozenlistAddresses(targetAddresses, added, skipped);
    }

    /**
     * @notice Removes multiple addresses from the frozenlist.
     * @dev Does not revert if an address is not listed.
     * @param targetAddresses Addresses to remove from the frozenlist.
     */
    function removeFrozenlistAddresses(address[] calldata targetAddresses) public virtual onlyFrozenlistRemove {
        (uint256 removed, uint256 skipped) = _removeFrozenlistAddresses(targetAddresses);
        emit RemoveFrozenlistAddresses(targetAddresses, removed, skipped);
    }

    /**
     * @notice Adds a single address to the frozenlist.
     * @dev
     * Reverts if the address is already listed.
     * Deviation from ERC-2980 `Freezable` example interface: the spec's `addAddressToFrozenlist`
     * returns `false` on duplicates instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to add to the frozenlist.
     */
    function addFrozenlistAddress(address targetAddress) public virtual onlyFrozenlistAdd {
        require(targetAddress != address(0), RuleERC2980_ZeroAddressNotAllowed());
        require(_addFrozenlistAddress(targetAddress), RuleERC2980_AddressAlreadyFrozen());
        emit AddFrozenlistAddress(targetAddress);
    }

    /**
     * @notice Removes a single address from the frozenlist.
     * @dev
     * Reverts if the address is not listed.
     * Deviation from ERC-2980 `Freezable` example interface: the spec's `removeAddressFromFrozenlist`
     * returns `false` when not found instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to remove from the frozenlist.
     */
    function removeFrozenlistAddress(address targetAddress) public virtual onlyFrozenlistRemove {
        require(_removeFrozenlistAddress(targetAddress), RuleERC2980_AddressNotFrozen());
        emit RemoveFrozenlistAddress(targetAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enables or disables minting through this rule.
     * @param value The new value of the `allowMint` flag.
     */
    function setAllowMint(bool value) public virtual onlyMintBurnManager {
        allowMint = value;
        emit AllowMintUpdated(value);
    }

    /**
     * @notice Enables or disables burning through this rule.
     * @param value The new value of the `allowBurn` flag.
     */
    function setAllowBurn(bool value) public virtual onlyMintBurnManager {
        allowBurn = value;
        emit AllowBurnUpdated(value);
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
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRule
     */
    function transferred(address spender, address from, address to, uint256 value) public view virtual override {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IRule
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode)
        public
        pure
        virtual
        override(IRule)
        returns (bool)
    {
        return restrictionCode == CODE_ADDRESS_FROM_IS_FROZEN || restrictionCode == CODE_ADDRESS_TO_IS_FROZEN
            || restrictionCode == CODE_ADDRESS_SPENDER_IS_FROZEN || restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED
            || restrictionCode == CODE_MINT_NOT_ALLOWED || restrictionCode == CODE_BURN_NOT_ALLOWED;
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        virtual
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_IS_FROZEN) {
            return TEXT_ADDRESS_FROM_IS_FROZEN;
        } else if (restrictionCode == CODE_ADDRESS_TO_IS_FROZEN) {
            return TEXT_ADDRESS_TO_IS_FROZEN;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_IS_FROZEN) {
            return TEXT_ADDRESS_SPENDER_IS_FROZEN;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED) {
            return TEXT_ADDRESS_TO_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_MINT_NOT_ALLOWED) {
            return TEXT_MINT_NOT_ALLOWED;
        } else if (restrictionCode == CODE_BURN_NOT_ALLOWED) {
            return TEXT_BURN_NOT_ALLOWED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        return RuleTransferValidation.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the number of whitelisted addresses.
     * @return The count of addresses currently in the whitelist.
     */
    function whitelistAddressCount() public view virtual returns (uint256) {
        return _whitelistCount();
    }

    /**
     * @notice Returns true if the address is in the whitelist.
     * @param targetAddress Address to check.
     * @return True if the address is whitelisted.
     */
    function isWhitelisted(address targetAddress) public view virtual returns (bool) {
        return _isWhitelisted(targetAddress);
    }

    /**
     * @notice ERC-2980 getter: returns true if the address is whitelisted.
     * @param _operator Address to check.
     * @return True if the address is whitelisted.
     */
    function whitelist(address _operator) public view virtual override(IERC2980) returns (bool) {
        return _isWhitelisted(_operator);
    }

    /**
     * @notice Returns true if the address is whitelisted (identity-verified).
     * @dev Reflects whitelist membership only. Frozen status is intentionally excluded:
     * freezing is a temporary enforcement action and does not revoke identity verification.
     * @param targetAddress Address to check.
     * @return True if the address is whitelisted.
     */
    function isVerified(address targetAddress) public view virtual override(IIdentityRegistryVerified) returns (bool) {
        return _isWhitelisted(targetAddress);
    }

    /**
     * @notice Checks multiple addresses for whitelist membership.
     * @param targetAddresses Addresses to check.
     * @return results Array of booleans, true where the corresponding address is whitelisted.
     */
    function areWhitelisted(address[] memory targetAddresses) public view virtual returns (bool[] memory results) {
        results = new bool[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; ++i) {
            results[i] = _isWhitelisted(targetAddresses[i]);
        }
    }

    /**
     * @notice Returns the number of frozen addresses.
     * @return The count of addresses currently in the frozenlist.
     */
    function frozenlistAddressCount() public view virtual returns (uint256) {
        return _frozenlistCount();
    }

    /**
     * @notice Returns true if the address is in the frozenlist.
     * @param targetAddress Address to check.
     * @return True if the address is frozen.
     */
    function isFrozen(address targetAddress) public view virtual returns (bool) {
        return _isFrozen(targetAddress);
    }

    /**
     * @notice ERC-2980 getter: returns true if the address is frozen.
     * @param _operator Address to check.
     * @return True if the address is frozen.
     */
    function frozenlist(address _operator) public view virtual override(IERC2980) returns (bool) {
        return _isFrozen(_operator);
    }

    /**
     * @notice Checks multiple addresses for frozenlist membership.
     * @param targetAddresses Addresses to check.
     * @return results Array of booleans, true where the corresponding address is frozen.
     */
    function areFrozen(address[] memory targetAddresses) public view virtual returns (bool[] memory results) {
        results = new bool[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; ++i) {
            results[i] = _isFrozen(targetAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorization hook invoked before toggling `allowMint` / `allowBurn`.
     */
    function _authorizeMintBurnManager() internal view virtual;

    /**
     * @notice Authorization hook invoked before adding addresses to the whitelist.
     */
    function _authorizeWhitelistAdd() internal view virtual;
    /**
     * @notice Authorization hook invoked before removing addresses from the whitelist.
     */
    function _authorizeWhitelistRemove() internal view virtual;
    /**
     * @notice Authorization hook invoked before adding addresses to the frozenlist.
     */
    function _authorizeFrozenlistAdd() internal view virtual;
    /**
     * @notice Authorization hook invoked before removing addresses from the frozenlist.
     */
    function _authorizeFrozenlistRemove() internal view virtual;

    /**
     * @inheritdoc RuleTransferValidation
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
        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        // Gate the mint/burn OPERATION explicitly, rather than by whitelisting the zero address.
        if (isMint && !allowMint) {
            return CODE_MINT_NOT_ALLOWED;
        }
        if (isBurn && !allowBurn) {
            return CODE_BURN_NOT_ALLOWED;
        }

        // Frozenlist check has priority — but only for REAL participants.
        if (!isMint && _isFrozen(from)) {
            return CODE_ADDRESS_FROM_IS_FROZEN;
        }
        if (!isBurn && _isFrozen(to)) {
            return CODE_ADDRESS_TO_IS_FROZEN;
        }
        // Whitelist check: only the recipient must be whitelisted (ERC-2980); no recipient on a burn.
        if (!isBurn && !_isWhitelisted(to)) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        if (_isFrozen(spender)) {
            return CODE_ADDRESS_SPENDER_IS_FROZEN;
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
            RuleERC2980_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleERC2980_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _msgSender() internal view virtual override(ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _msgData() internal view virtual override(ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
