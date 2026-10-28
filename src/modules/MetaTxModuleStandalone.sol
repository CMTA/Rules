//SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.27;

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

/**
 * @dev Meta transaction (gasless) module.
 */
abstract contract MetaTxModuleStandalone is ERC2771Context {
    /**
     * @notice Configures the trusted ERC-2771 forwarder used to recover the meta-transaction sender.
     * @param trustedForwarder The address allowed to forward meta-transactions on behalf of users.
     */
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {
        // Nothing to do
    }
}
