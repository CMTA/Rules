// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {MaxTotalSupplyHandler} from "./MaxTotalSupplyHandler.sol";

/**
 * @title IssuanceCapHandler
 * @notice Same actions and ghosts as {MaxTotalSupplyHandler}; only the definition of "fits" changes. A mint
 * fits when BOTH the live supply and the cumulative issuance stay within the cap. `ghostIssued` mirrors
 * the rule's counter independently: it rises on every accepted mint and never on a burn.
 */
contract IssuanceCapHandler is MaxTotalSupplyHandler {
    uint256 public ghostIssued;

    constructor(CMTATStandardStandalone token_, RuleIssuanceCap rule_) MaxTotalSupplyHandler(token_, rule_) {}

    function _fits(uint256 supplyBefore, uint256 value, uint256 cap) internal view override returns (bool) {
        return super._fits(supplyBefore, value, cap) && ghostIssued + value <= cap;
    }

    function _recordAccepted(uint256 supplyBefore, uint256 value, uint256 cap) internal override {
        super._recordAccepted(supplyBefore, value, cap); // judged against the issuance BEFORE this mint
        ghostIssued += value;
    }
}
