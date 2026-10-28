// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title MockERC20TransferFromFalse — ERC20-like mock whose transferFrom always fails
 * @notice Test double that tracks allowances but returns false from transferFrom,
 *         simulating a token whose transfer silently fails.
 */
contract MockERC20TransferFromFalse {
    /**
     * @notice Allowance amounts keyed by owner then spender.
     */
    mapping(address => mapping(address => uint256)) private _allowances;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the allowance granted by an owner to a spender.
     * @param owner The address granting the allowance.
     * @param spender The address being allowed to spend.
     * @param value The allowance amount to set.
     */
    function setAllowance(address owner, address spender, uint256 value) external {
        _allowances[owner][spender] = value;
    }

    /**
     * @notice Returns the allowance granted by an owner to a spender.
     * @param owner The address that granted the allowance.
     * @param spender The address allowed to spend.
     * @return The current allowance amount.
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Mock transferFrom that always fails by returning false.
     * @return Always false.
     */
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}
