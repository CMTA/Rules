// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleSpenderWhitelist} from "../../rules/validation/deployment/RuleSpenderWhitelist.sol";
import {RuleSpenderWhitelistOwnable2Step} from "../../rules/validation/deployment/RuleSpenderWhitelistOwnable2Step.sol";

/**
 * @title RuleSpenderWhitelistHarness — test harness exposing RuleSpenderWhitelist internals
 */
contract RuleSpenderWhitelistHarness is RuleSpenderWhitelist {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleSpenderWhitelist constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     */
    constructor(address admin, address forwarderIrrevocable) RuleSpenderWhitelist(admin, forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the internal `_msgSender()` resolved sender
     * @return Address returned by `_msgSender()`
     */
    function exposedMsgSender() external view returns (address) {
        return _msgSender();
    }

    /**
     * @notice Exposes the internal `_msgData()` calldata buffer
     * @return Calldata bytes returned by `_msgData()`
     */
    function exposedMsgData() external view returns (bytes memory) {
        return _msgData();
    }

    /**
     * @notice Exposes the internal `_contextSuffixLength()` value
     * @return Length in bytes of the ERC-2771 context suffix
     */
    function exposedContextSuffixLength() external view returns (uint256) {
        return _contextSuffixLength();
    }
}

/**
 * @title RuleSpenderWhitelistOwnable2StepHarness — test harness exposing RuleSpenderWhitelistOwnable2Step internals
 */
contract RuleSpenderWhitelistOwnable2StepHarness is RuleSpenderWhitelistOwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleSpenderWhitelistOwnable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     */
    constructor(address owner, address forwarderIrrevocable)
        RuleSpenderWhitelistOwnable2Step(owner, forwarderIrrevocable)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the internal `_msgSender()` resolved sender
     * @return Address returned by `_msgSender()`
     */
    function exposedMsgSender() external view returns (address) {
        return _msgSender();
    }

    /**
     * @notice Exposes the internal `_msgData()` calldata buffer
     * @return Calldata bytes returned by `_msgData()`
     */
    function exposedMsgData() external view returns (bytes memory) {
        return _msgData();
    }

    /**
     * @notice Exposes the internal `_contextSuffixLength()` value
     * @return Length in bytes of the ERC-2771 context suffix
     */
    function exposedContextSuffixLength() external view returns (uint256) {
        return _contextSuffixLength();
    }
}
