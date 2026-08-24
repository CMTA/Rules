// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "../../rules/interfaces/AggregatorV3Interface.sol";
import {ITotalSupply} from "../../rules/interfaces/ITotalSupply.sol";
import {RuleChainlinkPoR} from "../../rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleMaxBalance} from "../../rules/validation/deployment/RuleMaxBalance.sol";
import {RuleMaxTotalSupply} from "../../rules/validation/deployment/RuleMaxTotalSupply.sol";

/**
 * @title ERC-3643 cap-rule harnesses
 * @notice Worked examples of the two seams the cap rules expose, used by
 *         `test/CapAccounting/ERC3643CapSeams.t.sol` to prove they are sufficient.
 *
 * @dev **Seam 1 — accounting phase (`_detectTransferRestrictionOnNotify`).** CMTAT calls a rule
 * BEFORE it moves the value, so the observation excludes it. ERC-3643 / T-REX calls AFTER, so the
 * observation already includes it and counting `value` again halves the effective cap. Overriding the
 * notification hook to re-ask with `value = 0` is the whole adaptation.
 *
 * @dev **Seam 2 — observation source (`_currentSupply` / `_balanceOf`).** Both are `internal view
 * virtual`, so a rule may serve the figure from its own storage instead of calling the token. A rule
 * that keeps its own running total also controls when it is updated, which makes seam 1 moot for it.
 *
 * These are test doubles, not deployable rules. See
 * `doc/technical/guides/RULE_SEMANTICS.md` for the write-up.
 */

/// @notice `RuleMaxTotalSupply` for a token that notifies after minting.
contract ERC3643MaxTotalSupplyHarness is RuleMaxTotalSupply {
    constructor(address admin, address tokenContract_, uint256 maxTotalSupply_)
        RuleMaxTotalSupply(admin, tokenContract_, maxTotalSupply_)
    {}

    /// @dev Seam 1: the observation already includes the minted value.
    function _detectTransferRestrictionOnNotify(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        override
        returns (uint8)
    {
        // `totalSupply()` already includes the mint, so there is nothing left to add.
        return _detectTransferRestriction(from, to, 0);
    }
}

/// @notice `RuleMaxBalance` for a token that notifies after moving the value.
contract ERC3643MaxBalanceHarness is RuleMaxBalance {
    constructor(address admin, address balanceToken_, uint256 maxBalance_)
        RuleMaxBalance(admin, balanceToken_, maxBalance_)
    {}

    /// @dev Seam 1: the observation already includes the received value.
    function _detectTransferRestrictionOnNotify(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        override
        returns (uint8)
    {
        // `balanceOf(to)` already includes the received value.
        return _detectTransferRestriction(from, to, 0);
    }
}

/// @notice `RuleChainlinkPoR` for a token that notifies after minting.
contract ERC3643ChainlinkPoRHarness is RuleChainlinkPoR {
    constructor(
        address admin,
        address tokenContract_,
        uint8 tokenDecimals_,
        AggregatorV3Interface reservesFeed_,
        uint256 maxStalenessSeconds_
    ) RuleChainlinkPoR(admin, tokenContract_, tokenDecimals_, reservesFeed_, maxStalenessSeconds_) {}

    /// @dev Seam 1: the observation already includes the minted value.
    function _detectTransferRestrictionOnNotify(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, 0);
    }
}

/**
 * @notice `RuleMaxTotalSupply` serving the supply from its OWN storage instead of the token.
 * @dev Demonstrates seam 2. A real version would maintain {trackedSupply} from the write hook and is
 * a larger design: it must observe every supply change or it drifts. The same approach is NOT safe for
 * per-address balances: `Token.recoveryAddress` notifies compliance on T-REX <= 4.1 (it calls the public
 * `forcedTransfer`) but not on 4.2.0-beta1 (it calls `_transfer` directly), so a shadow ledger's
 * correctness would depend on the token's minor version. Total supply is unaffected by recovery.
 */
contract TrackedSupplyHarness is RuleMaxTotalSupply {
    /// @notice Supply as this rule believes it to be; never read from the token.
    uint256 public trackedSupply;

    constructor(address admin, address tokenContract_, uint256 maxTotalSupply_)
        RuleMaxTotalSupply(admin, tokenContract_, maxTotalSupply_)
    {}

    /// @notice Seeds the opening figure; a real rule would restrict and one-shot this.
    function setTrackedSupply(uint256 supply) external {
        trackedSupply = supply;
    }

    /// @dev Seam 2: the observation comes from storage, never from the token.
    function _currentSupply() internal view override returns (bool available, uint256 supply) {
        return (true, trackedSupply);
    }

    /// @dev Unused on the read path once {_currentSupply} is overridden.
    function _supplyToken() internal view override returns (ITotalSupply) {
        // Never consulted on the read path; kept so configuration stays valid.
        return tokenContract;
    }
}
