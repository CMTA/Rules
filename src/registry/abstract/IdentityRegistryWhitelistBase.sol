// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleAddressSetInternal} from "../../rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol";
import {IdentityRegistryWhitelistInvariantStorage} from "./IdentityRegistryWhitelistInvariantStorage.sol";
import {VersionModule} from "../../modules/VersionModule.sol";
import {IIdentityRegistryERC3643} from "../interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title IdentityRegistryWhitelistBase
 * @notice A whitelist that presents itself to an ERC-3643 token as an identity registry.
 * @dev Installed with `token.setIdentityRegistry(address(this))`. **Not** a compliance rule: no
 * `IRule` surface, and it must never be added to a `RuleEngine`.
 *
 * @dev **No identity data is stored** -- no ONCHAINID, no country, no claims. `registerIdentity`'s
 * `_identity` and `_country` are accepted so the ERC-3643 signature matches, then discarded, and
 * {investorCountry} always returns 0. Verification means one thing here: is this wallet listed.
 * `Token.sol` reads `investorCountry` only in `recoveryAddress`, to pass it straight back, so the
 * token is unaffected; a *custom* compliance module reading it would see every investor as country 0.
 *
 * @dev **No ERC-734 surface.** `keyHasPurpose` was implemented once and removed: `recoveryAddress`
 * calls it on the address the agent supplies, never cross-checking it against the registry, so it
 * gated nothing while costing a reverse index. Supply a real ONCHAINID as `_investorOnchainID`.
 *
 * @dev The address set is inherited from {RuleAddressSetInternal}, so the registry *is* the list.
 * Only the internal layer, so there is one write API (the ERC-3643 one), not two overlapping ones.
 */
abstract contract IdentityRegistryWhitelistBase is
    RuleAddressSetInternal,
    VersionModule,
    IIdentityRegistryERC3643,
    IdentityRegistryWhitelistInvariantStorage
{
    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Adds the wallet to the whitelist. `_identity` is echoed in {IdentityRegistered} for
     * off-chain traceability and `_country` is ignored entirely -- neither is stored.
     *
     * Reverts on the zero address and on an already-registered wallet, matching ERC-3643's
     * reference registry (which reverts with "address stored already").
     */
    function registerIdentity(
        address _userAddress,
        address _identity,
        uint16 /* _country */
    )
        external
        virtual
        override
        onlyIdentityRegistrar
    {
        // Same guards, same errors as the whitelist rules: the zero address is the mint/burn
        // sentinel and must never be listed, or `isVerified(address(0))` would return true.
        require(_userAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
        require(_addAddress(_userAddress), RuleAddressSet_AddressAlreadyListed());
        emit IdentityRegistered(_userAddress, _identity);
    }

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Reverts if the wallet is not registered.
     */
    function deleteIdentity(address _userAddress) external virtual override onlyIdentityRegistrar {
        require(_removeAddress(_userAddress), RuleAddressSet_AddressNotFound());
        emit IdentityRemoved(_userAddress);
    }

    /**
     * @notice Returns how many wallets are registered.
     * @dev There is deliberately no full enumeration getter, matching `RuleWhitelist` and
     * `RuleBlacklist`, which expose a count but not the member list.
     * @return The number of registered wallets.
     */
    function registeredIdentityCount() external view virtual returns (uint256) {
        return _listedAddressCount();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev `address(0)` is never registered, so it is never verified -- ERC-3643 defines
     * `isVerified` as "is this wallet a valid investor", and the zero address is not a wallet.
     * Mint and burn permission is the token's business, not the registry's.
     */
    function isVerified(address _userAddress) public view virtual override returns (bool) {
        return _isAddressListed(_userAddress);
    }

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Always returns 0: this registry keeps no identity data, only a whitelist. The function
     * exists because `recoveryAddress` calls it -- omitting it would make every recovery revert --
     * and the 0 it returns is handed straight back to {registerIdentity}, which ignores it.
     */
    function investorCountry(
        address /* _userAddress */
    )
        public
        view
        virtual
        override
        returns (uint16)
    {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyIdentityRegistrar() {
        _authorizeIdentityRegistrar();
        _;
    }

    /**
     * @notice Authorizes the caller to register and delete identities; reverts otherwise.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeIdentityRegistrar() internal view virtual;
}
