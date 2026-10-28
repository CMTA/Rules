// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControlModuleStandalone} from "../../../modules/AccessControlModuleStandalone.sol";
import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoRBase} from "../abstract/base/RuleChainlinkPoRBase.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";

/**
 * @title RuleChainlinkPoR
 * @notice Restricts minting so that the token's total supply never exceeds the reserves reported by
 * a Chainlink Proof of Reserve data feed.
 */
contract RuleChainlinkPoR is AccessControlModuleStandalone, RuleChainlinkPoRBase {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param admin Address that receives the default admin role.
     * @param tokenContract_ Token contract that exposes totalSupply (must be non-zero).
     * @param tokenDecimals_ Decimals of that token (0 to 18, checked against `decimals()` when exposed).
     * @param reservesFeed_ Proof of Reserve data feed implementing `AggregatorV3Interface`.
     * @param maxStalenessSeconds_ Initial staleness threshold in seconds; 0 disables the check.
     */
    constructor(
        address admin,
        address tokenContract_,
        uint8 tokenDecimals_,
        AggregatorV3Interface reservesFeed_,
        uint256 maxStalenessSeconds_
    )
        AccessControlModuleStandalone(admin)
        RuleChainlinkPoRBase(tokenContract_, tokenDecimals_, reservesFeed_, maxStalenessSeconds_)
    {}

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
        override(AccessControlEnumerable, RuleTransferValidation)
        returns (bool)
    {
        return AccessControlEnumerable.supportsInterface(interfaceId)
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts Proof of Reserve configuration to holders of DEFAULT_ADMIN_ROLE.
     */
    function _authorizeChainlinkPoRManager() internal view virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
