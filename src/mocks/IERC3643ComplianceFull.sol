// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title IERC3643ComplianceFull
 * @dev Flat interface redeclaring the complete ERC-3643 ICompliance function set,
 *      including functions inherited by IERC3643Compliance from its parent interfaces
 *      (IERC3643ComplianceRead.canTransfer, IERC3643IComplianceContract.transferred).
 *
 *      Purpose: pinning the ERC-165 interface ID of the full ERC-3643 ICompliance
 *      interface from an independent source. The rules themselves advertise
 *      `ComplianceInterfaceId.ERC3643_COMPLIANCE_INTERFACE_ID`, which RuleEngine derives from
 *      its own interface hierarchy; this flat redeclaration is the cross-check that the
 *      derivation still yields the wire value, so a refactor upstream cannot silently move it.
 *
 *      Background: `type(IFoo).interfaceId` only XORs selectors defined *directly* on
 *      `IFoo`, not those inherited from parent interfaces. Using `type(IERC3643Compliance).interfaceId`
 *      would therefore miss `canTransfer` and `transferred`.  This flat interface
 *      redeclares all eight functions so the XOR covers the full hierarchy.
 *
 *      Do NOT use this interface as a type annotation or for casting — use the actual
 *      `IERC3643Compliance` (from RuleEngine) for that.
 *
 *      Computed value: `type(IERC3643ComplianceFull).interfaceId == 0x3144991c`
 */
interface IERC3643ComplianceFull {
    // From IERC3643IComplianceContract
    /**
     * @notice Notifies the compliance contract that a transfer has occurred.
     * @param from The address tokens were transferred from.
     * @param to The address tokens were transferred to.
     * @param value The amount transferred.
     */
    function transferred(address from, address to, uint256 value) external;
    // From IERC3643Compliance (directly defined)
    /**
     * @notice Binds a token to the compliance contract.
     * @param token The token address to bind.
     */
    function bindToken(address token) external;
    /**
     * @notice Unbinds a token from the compliance contract.
     * @param token The token address to unbind.
     */
    function unbindToken(address token) external;
    /**
     * @notice Notifies the compliance contract that tokens have been created (minted).
     * @param to The address that received the newly created tokens.
     * @param value The amount created.
     */
    function created(address to, uint256 value) external;
    /**
     * @notice Notifies the compliance contract that tokens have been destroyed (burned).
     * @param from The address whose tokens were destroyed.
     * @param value The amount destroyed.
     */
    function destroyed(address from, uint256 value) external;

    // From IERC3643ComplianceRead
    /**
     * @notice Checks whether a transfer is compliant.
     * @param from The address tokens would be transferred from.
     * @param to The address tokens would be transferred to.
     * @param value The amount that would be transferred.
     * @return isValid True if the transfer is compliant.
     */
    function canTransfer(address from, address to, uint256 value) external view returns (bool isValid);
    /**
     * @notice Returns whether a token is bound to the compliance contract.
     * @param token The token address to query.
     * @return isBound True if the token is bound.
     */
    function isTokenBound(address token) external view returns (bool isBound);
    /**
     * @notice Returns the token currently bound to the compliance contract.
     * @return token The bound token address.
     */
    function getTokenBound() external view returns (address token);
}
