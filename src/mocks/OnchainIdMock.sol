// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IERC734KeyHasPurpose} from "../registry/interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title OnchainIdMock — the minimal ERC-734 surface `recoveryAddress` needs.
 * @notice `Token.recoveryAddress` calls `keyHasPurpose(keccak256(abi.encode(newWallet)), 1)` on the
 * `_investorOnchainID` address the agent supplies. In production that is the investor's ONCHAINID.
 * This stub stands in for it, letting a test decide which wallet keys it vouches for.
 *
 * @dev It records keys rather than returning a blanket `true` so the tests exercise the same shape
 * as a real identity: recovery succeeds only for a wallet the identity actually vouches for.
 *
 * WARNING: test stub only. Holds no real keys and performs no authorisation.
 */
contract OnchainIdMock is IERC734KeyHasPurpose {
    /**
     * @notice Keys this identity vouches for, per ERC-734 purpose.
     */
    mapping(bytes32 key => mapping(uint256 purpose => bool held)) private _keys;

    /**
     * @notice Vouches for a wallet, as an ONCHAINID holding a management key for it would.
     * @param wallet The wallet to vouch for.
     * @param purpose The ERC-734 purpose to grant (1 = MANAGEMENT).
     */
    function addWalletKey(address wallet, uint256 purpose) external {
        _keys[keccak256(abi.encode(wallet))][purpose] = true;
    }

    /**
     * @inheritdoc IERC734KeyHasPurpose
     */
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view override returns (bool) {
        return _keys[_key][_purpose];
    }
}
