// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {OwnableInterfaceId} from "RuleEngine/modules/library/OwnableInterfaceId.sol";
import {Ownable2StepInterfaceId} from "RuleEngine/modules/library/Ownable2StepInterfaceId.sol";

/**
 * @title Ownable2StepERC165Module
 * @notice Shared ERC-165 advertisement for Ownable2Step deployments.
 */
abstract contract Ownable2StepERC165Module is ERC165 {
    /**
     * @inheritdoc ERC165
     * @dev Also advertises support for the IERC173 and IOwnable2Step interfaces.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == OwnableInterfaceId.IERC173_INTERFACE_ID
            || interfaceId == Ownable2StepInterfaceId.IOWNABLE2STEP_INTERFACE_ID
            || ERC165.supportsInterface(interfaceId);
    }
}
