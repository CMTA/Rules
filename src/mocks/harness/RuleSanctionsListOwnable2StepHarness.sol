// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ISanctionsList} from "../../rules/interfaces/ISanctionsList.sol";
import {RuleSanctionsListOwnable2Step} from "../../rules/validation/deployment/RuleSanctionsListOwnable2Step.sol";

/**
 * @title RuleSanctionsListOwnable2StepHarness — test harness exposing RuleSanctionsListOwnable2Step internals
 */
contract RuleSanctionsListOwnable2StepHarness is RuleSanctionsListOwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleSanctionsListOwnable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param sanctionContractOracle_ Chainalysis sanctions oracle used to screen addresses
     */
    constructor(address owner, address forwarderIrrevocable, ISanctionsList sanctionContractOracle_)
        RuleSanctionsListOwnable2Step(owner, forwarderIrrevocable, sanctionContractOracle_)
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
