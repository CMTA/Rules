// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {ISanctionsList} from "../../rules/interfaces/ISanctionsList.sol";
import {RuleBlacklist} from "../../rules/validation/deployment/RuleBlacklist.sol";
import {RuleWhitelist} from "../../rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "../../rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleERC2980} from "../../rules/validation/deployment/RuleERC2980.sol";
import {RuleSanctionsList} from "../../rules/validation/deployment/RuleSanctionsList.sol";
import {RuleBlacklistOwnable2Step} from "../../rules/validation/deployment/RuleBlacklistOwnable2Step.sol";
import {RuleWhitelistOwnable2Step} from "../../rules/validation/deployment/RuleWhitelistOwnable2Step.sol";
import {RuleWhitelistWrapperOwnable2Step} from "../../rules/validation/deployment/RuleWhitelistWrapperOwnable2Step.sol";
import {RuleERC2980Ownable2Step} from "../../rules/validation/deployment/RuleERC2980Ownable2Step.sol";

/**
 * @title RuleBlacklistHarness — test harness exposing RuleBlacklist internals
 */
contract RuleBlacklistHarness is RuleBlacklist {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleBlacklist constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     */
    constructor(address admin, address forwarderIrrevocable) RuleBlacklist(admin, forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleWhitelistHarness — test harness exposing RuleWhitelist internals
 */
contract RuleWhitelistHarness is RuleWhitelist {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleWhitelist constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param checkSpender_ Whether the spender is also checked against the whitelist
     * @param allowMintBurn Whether mint and burn operations bypass the whitelist
     */
    constructor(address admin, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelist(admin, forwarderIrrevocable, checkSpender_, allowMintBurn)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleWhitelistWrapperHarness — test harness exposing RuleWhitelistWrapper internals
 */
contract RuleWhitelistWrapperHarness is RuleWhitelistWrapper {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleWhitelistWrapper constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param checkSpender_ Whether the spender is also checked against the whitelist
     * @param allowMintBurn Whether minting and burning are permitted (sets both flags)
     */
    constructor(address admin, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistWrapper(admin, forwarderIrrevocable, checkSpender_, allowMintBurn)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleERC2980Harness — test harness exposing RuleERC2980 internals
 */
contract RuleERC2980Harness is RuleERC2980 {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleERC2980 constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param allowBurn Whether burn operations are permitted
     */
    constructor(address admin, address forwarderIrrevocable, bool allowBurn)
        RuleERC2980(admin, forwarderIrrevocable, allowBurn)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleSanctionsListHarness — test harness exposing RuleSanctionsList internals
 */
contract RuleSanctionsListHarness is RuleSanctionsList {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleSanctionsList constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param sanctionContractOracle_ Chainalysis sanctions oracle used to screen addresses
     */
    constructor(address admin, address forwarderIrrevocable, ISanctionsList sanctionContractOracle_)
        RuleSanctionsList(admin, forwarderIrrevocable, sanctionContractOracle_)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleBlacklistOwnable2StepHarness — test harness exposing RuleBlacklistOwnable2Step internals
 */
contract RuleBlacklistOwnable2StepHarness is RuleBlacklistOwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleBlacklistOwnable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     */
    constructor(address owner, address forwarderIrrevocable) RuleBlacklistOwnable2Step(owner, forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleWhitelistOwnable2StepHarness — test harness exposing RuleWhitelistOwnable2Step internals
 */
contract RuleWhitelistOwnable2StepHarness is RuleWhitelistOwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleWhitelistOwnable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param checkSpender_ Whether the spender is also checked against the whitelist
     * @param allowMintBurn Whether mint and burn operations bypass the whitelist
     */
    constructor(address owner, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistOwnable2Step(owner, forwarderIrrevocable, checkSpender_, allowMintBurn)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleWhitelistWrapperOwnable2StepHarness — test harness exposing RuleWhitelistWrapperOwnable2Step internals
 */
contract RuleWhitelistWrapperOwnable2StepHarness is RuleWhitelistWrapperOwnable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleWhitelistWrapperOwnable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param checkSpender_ Whether the spender is also checked against the whitelist
     * @param allowMintBurn Whether minting and burning are permitted (sets both flags)
     */
    constructor(address owner, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistWrapperOwnable2Step(owner, forwarderIrrevocable, checkSpender_, allowMintBurn)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}

/**
 * @title RuleERC2980Ownable2StepHarness — test harness exposing RuleERC2980Ownable2Step internals
 */
contract RuleERC2980Ownable2StepHarness is RuleERC2980Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleERC2980Ownable2Step constructor
     * @param owner Address set as the contract owner
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param allowBurn Whether burn operations are permitted
     */
    constructor(address owner, address forwarderIrrevocable, bool allowBurn)
        RuleERC2980Ownable2Step(owner, forwarderIrrevocable, allowBurn)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the length of the internal `_msgData()` calldata buffer
     * @return Length in bytes of the value returned by `_msgData()`
     */
    function exposedMsgDataLength() external view returns (uint256) {
        return _msgData().length;
    }
}
