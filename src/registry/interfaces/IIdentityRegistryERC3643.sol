// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title IIdentityRegistryERC3643 — the subset of the ERC-3643 identity registry an ERC-3643 token
 * actually calls.
 * @notice ERC-3643's full `IIdentityRegistry` also declares `contains`, `identity`,
 * `updateIdentity`, `updateCountry`, `batchRegisterIdentity`, `identityStorage`, `issuersRegistry`
 * and `topicsRegistry`. **None of those are invoked by `Token.sol`**, so they are deliberately left
 * out here: a registry that implements only this interface is a complete drop-in for a token, and
 * omitting the rest keeps the contract small and its trust surface obvious.
 * @dev `_identity` is typed `address` rather than `IIdentity`. That is ABI-identical — Solidity
 * canonicalises contract types to `address` when computing selectors — so `registerIdentity` here
 * has exactly the same selector as ERC-3643's, without dragging in the ONCHAINID dependency.
 */
interface IIdentityRegistryERC3643 {
    /**
     * @notice Registers a wallet as a verified investor.
     * @dev Called by the token itself inside `recoveryAddress`, and by a registrar off-chain.
     * @param _userAddress The wallet to register.
     * @param _identity The investor's ONCHAINID contract.
     * @param _country The investor's country code (ISO-3166 numeric).
     */
    function registerIdentity(address _userAddress, address _identity, uint16 _country) external;

    /**
     * @notice Removes a wallet from the registry.
     * @dev Called by the token itself inside `recoveryAddress`.
     * @param _userAddress The wallet to remove.
     */
    function deleteIdentity(address _userAddress) external;

    /**
     * @notice Returns whether a wallet is a verified investor.
     * @dev Called by `transfer`, `transferFrom`, `forcedTransfer` and `mint`.
     * @param _userAddress The wallet to check.
     * @return True if the wallet is verified.
     */
    function isVerified(address _userAddress) external view returns (bool);

    /**
     * @notice Returns the country code recorded for a wallet.
     * @dev Called by `recoveryAddress` to carry the country over to the replacement wallet.
     * @param _userAddress The wallet to query.
     * @return The country code, or 0 when the wallet is not registered.
     */
    function investorCountry(address _userAddress) external view returns (uint16);
}

/**
 * @title IERC734KeyHasPurpose — the single ERC-734 getter `recoveryAddress` needs.
 * @notice `Token.recoveryAddress` calls `keyHasPurpose` on the **caller-supplied**
 * `_investorOnchainID` argument, not on anything the registry returns. Implementing this lets the
 * registry itself be passed as that argument, so no ONCHAINID deployment is required.
 */
interface IERC734KeyHasPurpose {
    /**
     * @notice Returns whether a key holds a given purpose.
     * @param _key The key, `keccak256(abi.encode(walletAddress))` in ERC-3643's usage.
     * @param _purpose The ERC-734 purpose (1 = MANAGEMENT).
     * @return True if the key holds the purpose.
     */
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view returns (bool);
}
