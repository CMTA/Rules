// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title IdentityRegistryWhitelistInvariantStorage — constants, events and errors for the
 * whitelist-backed ERC-3643 identity registry.
 */
abstract contract IdentityRegistryWhitelistInvariantStorage {
    /* ============ Constants ============ */

    /**
     * @notice Role allowed to register and delete identities.
     * @dev The ERC-3643 token itself must hold this role, because `recoveryAddress` makes the token
     * call `registerIdentity` and `deleteIdentity` on the registry. See the technical doc.
     */
    bytes32 public constant IDENTITY_REGISTRAR_ROLE = keccak256("IDENTITY_REGISTRAR_ROLE");

    /* ============ Events ============ */

    /**
     * @notice Emitted when a wallet is added to the whitelist.
     * @param userAddress The registered wallet.
     * @param identity The ONCHAINID passed by the caller. Echoed for off-chain traceability only --
     * this registry stores no identity data. The `_country` argument is not echoed because it is
     * ignored entirely.
     */
    event IdentityRegistered(address indexed userAddress, address indexed identity);
    /**
     * @notice Emitted when a wallet is removed from the registry.
     * @param userAddress The removed wallet.
     */
    event IdentityRemoved(address indexed userAddress);

    /* ============ Errors ============ */

    // The zero-address and not-listed conditions deliberately reuse the address-set errors
    // (`RuleAddressSet_ZeroAddressNotAllowed`, `RuleAddressSet_AddressNotFound`) inherited with
    // `RuleAddressSetInternal`, so this registry reverts identically to the whitelist rules.
}
