// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoRBase} from "../abstract/base/RuleChainlinkPoRBase.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";

/**
 * @title RuleChainlinkPoROwnable2Step
 * @notice Ownable2Step variant of RuleChainlinkPoR.
 */
contract RuleChainlinkPoROwnable2Step is RuleChainlinkPoRBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param tokenDecimals_ Decimals of that token (0 to 18, checked against `decimals()` when exposed).
     * @param reservesFeed_ Proof of Reserve data feed implementing `AggregatorV3Interface`.
     * @param maxStalenessSeconds_ Initial staleness threshold in seconds; 0 disables the check.
     */
    constructor(
        address owner,
        address tokenContract_,
        uint8 tokenDecimals_,
        AggregatorV3Interface reservesFeed_,
        uint256 maxStalenessSeconds_
    ) RuleChainlinkPoRBase(tokenContract_, tokenDecimals_, reservesFeed_, maxStalenessSeconds_) Ownable(owner) {}

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Indicates whether this contract supports a given interface.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(RuleTransferValidation, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts Proof of Reserve configuration to the contract owner.
     */
    function _authorizeChainlinkPoRManager() internal view virtual override onlyOwner {}
}
