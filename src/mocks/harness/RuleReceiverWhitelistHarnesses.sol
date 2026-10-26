// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {RuleReceiverWhitelist} from "../../rules/validation/deployment/RuleReceiverWhitelist.sol";
import {
    RuleReceiverWhitelistOwnable2Step
} from "../../rules/validation/deployment/RuleReceiverWhitelistOwnable2Step.sol";

/**
 * @title RuleReceiverWhitelistHarness — test harness exposing RuleReceiverWhitelist internals
 */
contract RuleReceiverWhitelistHarness is RuleReceiverWhitelist {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleReceiverWhitelist constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     */
    constructor(address admin, address forwarderIrrevocable) RuleReceiverWhitelist(admin, forwarderIrrevocable) {}

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
 * @title RuleReceiverWhitelistOwnable2StepHarness — test harness exposing RuleReceiverWhitelistOwnable2Step internals
 */
contract RuleReceiverWhitelistOwnable2StepHarness is RuleReceiverWhitelistOwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleReceiverWhitelistOwnable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     */
    constructor(address owner, address forwarderIrrevocable)
        RuleReceiverWhitelistOwnable2Step(owner, forwarderIrrevocable)
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
