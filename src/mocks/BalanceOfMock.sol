// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

/**
 * @title BalanceOfMock — test double exposing settable per-address balances
 * @notice Stores balances that tests can set and read back, and can be made to revert on demand so
 * the revert-free read path of {RuleMaxBalanceBase} can be exercised.
 */
contract BalanceOfMock {
    /**
     * @notice Error raised by {balanceOf} while the mock is in its reverting mode.
     */
    error BalanceOfMock_Reverting();

    /**
     * @notice Stored balance per address.
     */
    mapping(address => uint256) private _balances;
    /**
     * @notice When true, `balanceOf` reverts, simulating a token that broke after configuration.
     */
    bool public reverting;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the balance of an address.
     * @param account The address whose balance is set.
     * @param newBalance The balance to store.
     */
    function setBalance(address account, uint256 newBalance) external {
        _balances[account] = newBalance;
    }

    /**
     * @notice Makes subsequent `balanceOf` calls revert, or stops them reverting.
     * @param newReverting True to make `balanceOf` revert.
     */
    function setReverting(bool newReverting) external {
        reverting = newReverting;
    }

    /**
     * @notice Returns the stored balance of an address.
     * @param account The address to query.
     * @return The stored balance.
     */
    function balanceOf(address account) external view returns (uint256) {
        require(!reverting, BalanceOfMock_Reverting());
        return _balances[account];
    }
}
