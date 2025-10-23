//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "CMTAT/deployment/CMTATStandalone.sol";
import "CMTAT/libraries/Errors.sol";

// RuleEngine
import {RuleEngineInvariantStorage} from "RuleEngine/modules/library/RuleEngineInvariantStorage.sol";
import {RuleEngine} from "RuleEngine/RuleEngine.sol";

// RuleSanctionList
import {RuleSanctionsList} from "src/rules/validation/RuleSanctionsList.sol";
// RUleBlackList
import {RuleBlacklist} from "src/rules/validation/RuleBlacklist.sol";
import {RuleBlacklistInvariantStorage} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleBlacklistInvariantStorage.sol";
// RuleWhitelist
import {RuleWhitelist} from "src/rules/validation/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/RuleWhitelistWrapper.sol";
import {RuleWhitelistInvariantStorage} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleWhitelistInvariantStorage.sol";
import {RuleAddressSetInvariantStorage} from "src/rules/validation/abstract/RuleAddressSet/invariantStorage/RuleAddressSetInvariantStorage.sol";

import {RuleSanctionsListInvariantStorage}from "src/rules/validation/abstract/RuleSanctionsListInvariantStorage.sol";
// Rule interface

// utils
import "RuleEngine/../test/utils/CMTATDeployment.sol";

/**
 * @title Constants used by the tests
 */
abstract contract HelperContract is
    RuleWhitelistInvariantStorage,
    RuleBlacklistInvariantStorage,
    RuleAddressSetInvariantStorage,
    RuleSanctionsListInvariantStorage,
    RuleEngineInvariantStorage
{
    // Test result
    uint256 internal resUint256;
    uint8 internal resUint8;
    bool internal resBool;
    bool internal resCallBool;
    string internal resString;
    // EOA to perform tests
    address constant ZERO_ADDRESS = address(0);
    address constant DEFAULT_ADMIN_ADDRESS = address(1);
    address constant WHITELIST_OPERATOR_ADDRESS = address(2);
    address constant RULE_ENGINE_OPERATOR_ADDRESS = address(3);
    address constant SANCTIONLIST_OPERATOR_ADDRESS = address(8);
    address constant CONDITIONAL_TRANSFER_OPERATOR_ADDRESS = address(9);
    address constant ATTACKER = address(4);
    address constant ADDRESS1 = address(5);
    address constant ADDRESS2 = address(6);
    address constant ADDRESS3 = address(7);
    // role string
    string constant RULE_ENGINE_ROLE_HASH =
        "0x774b3c5f4a8b37a7da21d72b7f2429e4a6d49c4de0ac5f2b831a1a539d0f0fd2";
    string constant WHITELIST_ROLE_HASH =
        "0xdc72ed553f2544c34465af23b847953efeb813428162d767f9ba5f4013be6760";
    string constant DEFAULT_ADMIN_ROLE_HASH =
        "0x0000000000000000000000000000000000000000000000000000000000000000";

    uint256 DEFAULT_TIME_LIMIT_TO_APPROVE = 7 days;
    uint256 DEFAULT_TIME_LIMIT_TO_TRANSFER = 7 days;
    // contract
    RuleBlacklist public ruleBlacklist;
    RuleWhitelist public ruleWhitelist;

    // CMTAT
    CMTATDeployment cmtatDeployment;
    CMTATStandalone CMTAT_CONTRACT;

    // RuleEngine Mock
    RuleEngine public ruleEngineMock;

    //bytes32 public constant RULE_ENGINE_ROLE = keccak256("RULE_ENGINE_ROLE");

    uint8 constant NO_ERROR = 0;
    uint8 CODE_NONEXISTENT = 255;
    // Defined in CMTAT.sol
    uint8 constant TRANSFER_OK = 0;
    string constant TEXT_TRANSFER_OK = "NoRestriction";
    // Forwarder
    string ERC2771ForwarderDomain = "ERC2771ForwarderDomain";

    error Rulelist_AddressAlreadylisted();
    error Rulelist_AddressNotPresent();

    constructor() {}
}
