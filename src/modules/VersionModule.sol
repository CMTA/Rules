// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC3643Version} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";

/**
 * @title VersionModule
 * @notice Exposes the contract version as required by ERC-3643.
 */
abstract contract VersionModule is IERC3643Version {
    /**
     * @notice The contract version string returned by {version}.
     */
    string private constant VERSION = "0.6.0";

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC3643Version
     */
    function version() public pure virtual override returns (string memory version_) {
        return VERSION;
    }
}
