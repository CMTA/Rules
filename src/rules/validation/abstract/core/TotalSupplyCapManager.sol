// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleMaxTotalSupplyInvariantStorage} from "../invariant/RuleMaxTotalSupplyInvariantStorage.sol";
import {ITotalSupply} from "../../../interfaces/ITotalSupply.sol";
import {TokenSupplyReader} from "./TokenSupplyReader.sol";
import {CapAccounting} from "./CapAccounting.sol";

/**
 * @title TotalSupplyCapManager
 * @notice A static total-supply ceiling: which token to observe, what the cap is, and whether a
 * prospective mint fits under it.
 *
 * @dev Declares **no constructor** and does not depend on **ERC-1404**, so the inheriting rule
 * decides when configuration happens (constructor or initializer) and owns the restriction-code
 * mapping; {_capExceeded} answers in booleans.
 *
 * @dev The revert-free `totalSupply()` read and the configuration probe come from
 * {TokenSupplyReader} via {_supplyToken}; the deployment precondition documented there applies
 * unchanged.
 */
abstract contract TotalSupplyCapManager is CapAccounting, TokenSupplyReader, RuleMaxTotalSupplyInvariantStorage {
    /**
     * @dev tokenContract is trusted to report an *accurate* totalSupply -- nothing on-chain can
     * verify that -- but it is NOT trusted to stay callable: a reverting or codeless token yields
     * {CODE_SUPPLY_ORACLE_UNAVAILABLE} instead of reverting the MUST-NOT-revert views.
     */
    ITotalSupply public tokenContract;
    /**
     * @notice Maximum total supply; minting that would exceed this value is rejected.
     */
    uint256 public maxTotalSupply;

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMaxTotalSupplyManager() {
        _authorizeMaxTotalSupplyManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the maximum total supply.
     * @param newMaxTotalSupply New maximum total supply value.
     */
    function setMaxTotalSupply(uint256 newMaxTotalSupply) public virtual onlyMaxTotalSupplyManager {
        _setMaxTotalSupply(newMaxTotalSupply);
    }

    /**
     * @notice Updates the token contract whose total supply is checked.
     * @param newTokenContract New token contract address; must not be the zero address.
     */
    function setTokenContract(address newTokenContract) public virtual onlyMaxTotalSupplyManager {
        _setTokenContract(newTokenContract);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stores the supply cap and emits {MaxTotalSupplyUpdated}.
     * @dev Shared by the constructor and {setMaxTotalSupply} so the event is emitted on every
     * assignment, including the initial one.
     * @param newMaxTotalSupply The new maximum total supply.
     */
    function _setMaxTotalSupply(uint256 newMaxTotalSupply) internal virtual {
        maxTotalSupply = newMaxTotalSupply;
        emit MaxTotalSupplyUpdated(newMaxTotalSupply);
    }

    /**
     * @notice Validates and stores the observed token and emits {TokenContractUpdated}.
     * @dev Shared by the constructor and {setTokenContract}; see {_setMaxTotalSupply}.
     * @param newTokenContract The new token contract.
     */
    function _setTokenContract(address newTokenContract) internal virtual {
        _validateTokenContract(newTokenContract);
        tokenContract = ITotalSupply(newTokenContract);
        emit TokenContractUpdated(newTokenContract);
    }

    /**
     * @notice Validates a candidate token contract before it is stored.
     * @dev `totalSupply()` is mandatory -- the cap check cannot work without it -- so it is probed
     * here, turning what would otherwise be a silent read-path failure into a named configuration
     * error. The code-length check is explicit rather than relying on the uncatchable extcodesize
     * revert that the probe would incidentally produce.
     * @param candidate The token contract to validate.
     */
    function _validateTokenContract(address candidate) internal view virtual {
        require(candidate != address(0), RuleMaxTotalSupply_TokenAddressZeroNotAllowed());
        require(candidate.code.length != 0, RuleMaxTotalSupply_TokenIsNotAContract(candidate));
        require(_probeTotalSupplyCallable(candidate), RuleMaxTotalSupply_TokenTotalSupplyUnavailable(candidate));
    }

    /**
     * @notice Authorization hook invoked before updating the max total supply or token contract.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual;

    /**
     * @inheritdoc TokenSupplyReader
     */
    function _supplyToken() internal view virtual override returns (ITotalSupply) {
        return tokenContract;
    }

    /**
     * @notice Reports whether minting `value` would breach the cap, without ever reverting.
     * @dev Answers in booleans rather than restriction codes, so the caller owns the ERC-1404
     * mapping. Overflow-safe: `currentSupply + value` could exceed uint256 on a MUST-NOT-revert
     * path, so the comparison uses the remaining headroom instead.
     * @param value The amount that would be minted.
     * @return supplyAvailable False when `totalSupply()` could not be read; the other return value
     * is then meaningless and the caller should treat the check as failed.
     * @return exceeded True when the mint would push total supply past {maxTotalSupply}.
     */
    function _capExceeded(uint256 value) internal view virtual returns (bool supplyAvailable, bool exceeded) {
        uint256 currentSupply;
        (supplyAvailable, currentSupply) = _currentSupply();
        if (!supplyAvailable) {
            return (false, false);
        }
        return (true, _capExceededBy(currentSupply, maxTotalSupply, value));
    }
}
