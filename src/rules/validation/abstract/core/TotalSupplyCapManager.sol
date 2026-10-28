// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

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
     * @dev In token BASE UNITS, compared as-is with `totalSupply()`: no decimals scaling is applied.
     * WARNING: on an 18-decimal token, `1_000_000` caps the supply at 10^-12 tokens and freezes minting;
     * one million whole tokens is `1_000_000 * 10 ** 18`.
     */
    uint256 public maxTotalSupply;

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMaxTotalSupplyManager() {
        _authorizeMaxTotalSupplyManager();
        _;
    }

    modifier onlyTokenContractManager() {
        _authorizeTokenContractManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the maximum total supply.
     * @param newMaxTotalSupply New maximum total supply, in token base units (see {maxTotalSupply}).
     */
    function setMaxTotalSupply(uint256 newMaxTotalSupply) public virtual onlyMaxTotalSupplyManager {
        _setMaxTotalSupply(newMaxTotalSupply);
    }

    /**
     * @notice Raises the cap by `amount`.
     * @dev Relative, so two independently approved increases compose (each adds its own amount),
     * where two absolute {setMaxTotalSupply} calls computed from the same old cap would overwrite each
     * other. Emits {MaxTotalSupplyUpdated} with the previous and new cap.
     * @param amount Amount to add, in token base units (see {maxTotalSupply}).
     */
    function increaseMaxTotalSupply(uint256 amount) public virtual onlyMaxTotalSupplyManager {
        uint256 current = maxTotalSupply;
        require(amount <= type(uint256).max - current, RuleMaxTotalSupply_IncreaseOverflow(current, amount));
        _setMaxTotalSupply(current + amount);
    }

    /**
     * @notice Lowers the cap by `amount`; reverts if `amount` exceeds the current cap.
     * @dev Lowering the cap below the current supply is allowed: it freezes minting while transfers
     * and burns continue. Emits {MaxTotalSupplyUpdated} with the previous and new cap.
     * @param amount Amount to subtract, in token base units (see {maxTotalSupply}).
     */
    function decreaseMaxTotalSupply(uint256 amount) public virtual onlyMaxTotalSupplyManager {
        uint256 current = maxTotalSupply;
        require(amount <= current, RuleMaxTotalSupply_DecreaseBelowZero(current, amount));
        _setMaxTotalSupply(current - amount);
    }

    /**
     * @notice Updates the token contract whose total supply is checked.
     * @param newTokenContract New token contract address; must not be the zero address.
     */
    function setTokenContract(address newTokenContract) public virtual onlyTokenContractManager {
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
        uint256 previousMaxTotalSupply = maxTotalSupply;
        maxTotalSupply = newMaxTotalSupply;
        emit MaxTotalSupplyUpdated(previousMaxTotalSupply, newMaxTotalSupply);
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
     * @notice Authorization hook invoked before updating the max total supply.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual;

    /**
     * @notice Authorization hook invoked before repointing the observed token.
     * @dev Separate from {_authorizeMaxTotalSupplyManager} on purpose: repointing the token changes the
     * protected supply as thoroughly as changing the cap, so it can stay with a stricter authority than
     * the one allowed to adjust the cap.
     */
    function _authorizeTokenContractManager() internal view virtual;

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

    /**
     * @notice How much may still be minted before total supply reaches the cap, without ever reverting.
     * @dev Kept `internal`: the rule wraps it in a public `remainingMintable` that reports an ERC-1404
     * restriction code, a concern this contract does not carry. Saturates at `0` when the cap has been
     * lowered below the current supply.
     * @return supplyAvailable False when `totalSupply()` could not be read; `headroom` is then
     * meaningless and the caller should treat the query as failed.
     * @return headroom Remaining mintable amount in token units.
     */
    function _remainingMintable() internal view virtual returns (bool supplyAvailable, uint256 headroom) {
        uint256 currentSupply;
        (supplyAvailable, currentSupply) = _currentSupply();
        if (!supplyAvailable) {
            return (false, 0);
        }
        return (true, _capHeadroom(currentSupply, maxTotalSupply));
    }
}
