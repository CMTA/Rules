// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSet} from "../RuleAddressSet/RuleAddressSet.sol";
import {RuleWhitelistShared} from "../core/RuleWhitelistShared.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";
import {AddressListInterfaceId} from "../../../interfaces/library/AddressListInterfaceId.sol";

/**
 * @title RuleWhitelistBase
 * @notice Core whitelist logic without access-control policy.
 */
abstract contract RuleWhitelistBase is RuleAddressSet, RuleWhitelistShared, IIdentityRegistryVerified {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the whitelist rule base.
     * @dev `allowMintBurn` sets BOTH {allowMint} and {allowBurn} — the common case, since mint and
     *      burn are normally permitted for a whitelist rule. Use {setAllowMint} / {setAllowBurn}
     *      afterwards for independent control (e.g. to permanently close issuance while still
     *      allowing redemptions).
     * @dev Mint/burn permission is an explicit flag and NO LONGER whitelists `address(0)`: the zero
     *      address is the ERC-20 sentinel, not a participant, and listing it made
     *      `isVerified(address(0))` return `true` in violation of ERC-3643.
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address for meta-transactions.
     * @param checkSpender_ Whether to also verify the spender on delegated transfers.
     * @param allowMintBurn When true, permits both minting and burning.
     */
    constructor(address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleAddressSet(forwarderIrrevocable)
    {
        _setCheckSpender(checkSpender_);
        _setAllowMintBurn(allowMintBurn, allowMintBurn);
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IIdentityRegistryVerified
     */
    function isVerified(address targetAddress)
        public
        view
        virtual
        override(IIdentityRegistryVerified)
        returns (bool isListed)
    {
        isListed = _isAddressListed(targetAddress);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        // Advertise IAddressList: this rule manages an address set and is usable as a
        // child rule of RuleWhitelistWrapper, which calls it through IAddressList.
        return interfaceId == AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID
            || interfaceId == AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Detects whether a direct transfer is restricted by the whitelist.
     * @param from The sender address.
     * @param to The recipient address.
     * @return The restriction code, or TRANSFER_OK when both parties are whitelisted.
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

        // Gate the mint/burn OPERATION explicitly, rather than by listing the zero address.
        uint8 mintBurnCode = _detectMintBurnRestriction(from, to);
        if (mintBurnCode != uint8(REJECTED_CODE_BASE.TRANSFER_OK)) {
            return mintBurnCode;
        }

        // Screen only the REAL participants. A permitted mint still requires a whitelisted
        // recipient; a permitted burn still requires a whitelisted sender.
        if (!isMint && !isAddressListed(from)) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        }
        if (!isBurn && !isAddressListed(to)) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects whether a delegated transfer is restricted by the whitelist.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     * @return The restriction code, or TRANSFER_OK when allowed.
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
        if (checkSpender && from != address(0) && to != address(0) && !isAddressListed(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return _detectTransferRestriction(from, to, value);
    }
}
