// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title TotalSupplyMock — test double exposing a settable total supply
 * @notice Stores a total supply value that tests can set and read back.
 */
contract TotalSupplyMock {
    /**
     * @notice The stored total supply value.
     */
    uint256 private _totalSupply;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the total supply value.
     * @param newTotalSupply The new total supply to store.
     */
    function setTotalSupply(uint256 newTotalSupply) external {
        _totalSupply = newTotalSupply;
    }

    /**
     * @notice Returns the stored total supply.
     * @return The current total supply value.
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
}
