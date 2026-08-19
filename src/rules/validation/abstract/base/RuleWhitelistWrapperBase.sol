// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/* ==== Abstract contracts === */
import {MetaTxModuleStandalone, ERC2771Context} from "../../../../modules/MetaTxModuleStandalone.sol";
import {RuleWhitelistShared} from "../core/RuleWhitelistShared.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
/* ==== RuleEngine === */
import {RulesManagementModule} from "RuleEngine/modules/RulesManagementModule.sol";
/* ==== Interfaces === */
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IAddressListBatchQuery} from "../../../interfaces/IAddressList.sol";
import {AddressListInterfaceId} from "../../../interfaces/library/AddressListInterfaceId.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";

/**
 * @title Wrapper to call several different whitelist rules (base)
 * @dev Child rules must implement {IAddressList} and must be ALLOW-lists.
 *
 * WARNING: {IAddressList} carries membership, not polarity. This wrapper ORs its children's
 * `areAddressesListed` answers and reads `true` as ELIGIBLE. A deny-list such as `RuleBlacklist`
 * satisfies the same interface and passes every check {addRule} performs, yet its set means the
 * opposite: add one as a child and its blacklisted addresses become whitelisted, and {isVerified}
 * reports them as verified investors. An ERC-165 guard would not catch this -- a blacklist advertises
 * the same interface id, because the interface really is the same. Polarity is configuration
 * discipline enforced by the rules manager, not by this contract. Nethermind AuditAgent NM-20.
 */
abstract contract RuleWhitelistWrapperBase is
    RulesManagementModule,
    MetaTxModuleStandalone,
    RuleWhitelistShared,
    IIdentityRegistryVerified
{
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deploys the whitelist wrapper base.
     * @dev The wrapper holds no addresses of its own — it ORs its child rules. It therefore needs its
     *      OWN mint/burn flags: the children no longer list `address(0)`, so without these a mint
     *      would resolve `from` as unlisted and be rejected.
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     * @param checkSpender_ Whether to also verify the spender on delegated transfers.
     * @param allowMintBurn When true, permits both minting and burning.
     */
    constructor(address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        MetaTxModuleStandalone(forwarderIrrevocable)
    {
        _setCheckSpender(checkSpender_);
        _setAllowMintBurn(allowMintBurn, allowMintBurn);
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        return RuleTransferValidation.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns true if the address is listed in at least one child whitelist rule.
     * @dev Delegates to {_isListedInAnyChild}, the same single-address resolution the mint and burn
     *      branches of {_detectTransferRestriction} use, so the ERC-3643 eligibility view and the
     *      transfer check can never disagree about an address.
     * @param targetAddress The address to check across all child whitelist rules.
     * @return True if the address is listed in at least one child rule.
     */
    function isVerified(address targetAddress) public view virtual override(IIdentityRegistryVerified) returns (bool) {
        return _isListedInAnyChild(targetAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Go through all the whitelist rules to know if a restriction exists on the transfer
     * @param from the origin address
     * @param to the destination address
     * @return The restricion code or REJECTED_CODE_BASE.TRANSFER_OK
     *
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
        // Gate the mint/burn OPERATION explicitly, before consulting any child rule.
        uint8 mintBurnCode = _detectMintBurnRestriction(from, to);
        if (mintBurnCode != uint8(REJECTED_CODE_BASE.TRANSFER_OK)) {
            return mintBurnCode;
        }

        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        // Resolve only the REAL participants against the children: the zero address is a sentinel,
        // not a listed member of any child, so asking about it would always fail.
        // Degenerate (0, 0): neither leg is a real participant, so there is nothing to screen.
        // Handled explicitly so the wrapper and {RuleWhitelistBase} return the same answer — the two
        // share `_detectMintBurnRestriction` precisely so they cannot drift.
        if (isMint && isBurn) {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
        if (isMint) {
            if (!_isListedInAnyChild(to)) {
                return CODE_ADDRESS_TO_NOT_WHITELISTED;
            }
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
        if (isBurn) {
            if (!_isListedInAnyChild(from)) {
                return CODE_ADDRESS_FROM_NOT_WHITELISTED;
            }
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }

        address[] memory targetAddress = new address[](2);
        targetAddress[0] = from;
        targetAddress[1] = to;

        bool[] memory result = _detectTransferRestrictionForTargets(targetAddress);
        if (!result[0]) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!result[1]) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    /**
     * @notice Returns true when `targetAddress` is listed in at least one child rule.
     * @param targetAddress The address to resolve across the children.
     * @return True if listed in any child.
     */
    function _isListedInAnyChild(address targetAddress) internal view virtual returns (bool) {
        address[] memory targets = new address[](1);
        targets[0] = targetAddress;
        return _detectTransferRestrictionForTargets(targets)[0];
    }

    /**
     * @notice Go through all the whitelist rules to know if a delegated transfer is restricted.
     * @param spender The delegated spender address.
     * @param from The origin address.
     * @param to The destination address.
     * @param value The amount transferred.
     * @return The restriction code or REJECTED_CODE_BASE.TRANSFER_OK.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Mint (from == address(0)) and burn (to == address(0)) are exempt from the spender check:
        // the minter/burner acts on its own authority, not as a delegated ERC-20 spender.
        if (!checkSpender || from == address(0) || to == address(0)) {
            return _detectTransferRestriction(from, to, value);
        }

        address[] memory targetAddress = new address[](3);
        targetAddress[0] = from;
        targetAddress[1] = to;
        targetAddress[2] = spender;

        bool[] memory result = _detectTransferRestrictionForTargets(targetAddress);

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

    // ERC-7943 tokenId overloads are provided by {RuleNFTAdapter} via RuleWhitelistShared.

    /**
     * @notice Reverts if a direct transfer is blocked by any child whitelist rule.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferred(address from, address to, uint256 value)
        internal
        view
        virtual
        override(RulesManagementModule, RuleWhitelistShared)
    {
        RuleWhitelistShared._transferred(from, to, value);
    }

    /**
     * @notice Reverts if a delegated transfer is blocked by any child whitelist rule.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferred(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override(RulesManagementModule)
    {
        RuleWhitelistShared._transferredFrom(spender, from, to, value);
    }

    /**
     * @notice Rejects a child rule that cannot answer the only question this wrapper asks it.
     * @dev Mirrors `RuleEngineBase._checkRule`, which guards its own children the same way. The
     * requirement is {IAddressListBatchQuery} — a single function — rather than the whole of
     * {IAddressList}, because `areAddressesListed` is the only function the wrapper ever calls;
     * demanding the full interface would also require four write functions and three further reads,
     * excluding a read-only child that works perfectly.
     *
     * `ERC165Checker.supportsInterface` is itself non-reverting -- a bounded staticcall returning
     * false for a codeless address, a missing selector or malformed return data -- so a hostile
     * candidate cannot brick the setter screening it.
     *
     * WARNING: this cannot check POLARITY. A deny-list answers `areAddressesListed` just as
     * faithfully as an allow-list and advertises the same id, so it passes here and then inverts the
     * wrapper's meaning. Children must be allow-lists by configuration; see the contract-level note.
     * @param rule_ The candidate child rule.
     */
    function _checkRule(address rule_) internal view virtual override {
        RulesManagementModule._checkRule(rule_);
        require(
            ERC165Checker.supportsInterface(rule_, AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID),
            RuleWhitelistWrapper_ChildIsNotAnAddressList(rule_)
        );
    }

    /**
     * @notice Evaluates target addresses across all child rules.
     * @param targetAddress Addresses to validate (from/to[/spender]).
     * @return result Boolean array aligned with targetAddress indicating if each address is listed.
     */
    function _detectTransferRestrictionForTargets(address[] memory targetAddress)
        internal
        view
        virtual
        returns (bool[] memory)
    {
        uint256 rulesLength = rulesCount();
        uint256 targetsLength = targetAddress.length;
        bool[] memory result = new bool[](targetsLength);
        // Number of targets not yet found in any child. Decremented the first time a target is
        // resolved, so the early exit below is an O(1) test rather than a full rescan of `result`
        // on every child rule. The observable result is identical.
        uint256 unresolved = targetsLength;
        for (uint256 i = 0; i < rulesLength; ++i) {
            // Call the whitelist rules
            // Gas cost grows with the number of rules. Keep the wrapper list bounded.
            bool[] memory isListed = IAddressListBatchQuery(rule(i)).areAddressesListed(targetAddress);
            for (uint256 j = 0; j < targetsLength; ++j) {
                if (isListed[j] && !result[j]) {
                    result[j] = true;
                    --unresolved;
                }
            }

            // Break early if all listed
            if (unresolved == 0) {
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
     * @return sender The effective message sender, unwrapped from the meta-transaction if present.
     */
    function _msgSender() internal view virtual override(ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     * @return The effective calldata, unwrapped from the meta-transaction if present.
     */
    function _msgData() internal view virtual override(ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     * @return The length of the ERC-2771 context suffix appended to calldata.
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
