// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "./HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {RuleMaxBalanceOwnable2Step} from "src/rules/validation/deployment/RuleMaxBalanceOwnable2Step.sol";
import {BalanceOfMock} from "src/mocks/BalanceOfMock.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleChainlinkPoRERC3643} from "src/rules/validation/deployment/RuleChainlinkPoRERC3643.sol";
import {
    RuleChainlinkPoRERC3643Ownable2Step
} from "src/rules/validation/deployment/RuleChainlinkPoRERC3643Ownable2Step.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {TotalSupplyDecimalsMock} from "src/mocks/TotalSupplyDecimalsMock.sol";

contract VersionTest is Test, HelperContract {
    string constant EXPECTED_VERSION = "0.5.0";

    function testVersionRuleWhitelist() public {
        RuleWhitelist rule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleBlacklist() public {
        RuleBlacklist rule = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleSanctionsList() public {
        RuleSanctionsList rule =
            new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS));
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleMaxTotalSupply() public {
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(new TotalSupplyMock()), 0);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleMaxBalance() public {
        RuleMaxBalance rule = new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, address(new BalanceOfMock()), 0);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleMaxBalanceOwnable2Step() public {
        RuleMaxBalanceOwnable2Step rule =
            new RuleMaxBalanceOwnable2Step(DEFAULT_ADMIN_ADDRESS, address(new BalanceOfMock()), 0);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleWhitelistWrapper() public {
        RuleWhitelistWrapper rule = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleERC2980() public {
        RuleERC2980 rule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleConditionalTransferLight() public {
        RuleConditionalTransferLight rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleSpenderWhitelist() public {
        RuleSpenderWhitelist rule = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleReceiverWhitelist() public {
        RuleReceiverWhitelist rule = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleIdentityRegistry() public {
        RuleIdentityRegistry rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleChainlinkPoR() public {
        TotalSupplyDecimalsMock token = new TotalSupplyDecimalsMock(18);
        AggregatorV3Mock feed = new AggregatorV3Mock(8, 1000 * 1e8);
        RuleChainlinkPoR rule = new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), 18, AggregatorV3Interface(address(feed)), 1 days
        );
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleChainlinkPoRERC3643() public {
        TotalSupplyDecimalsMock token = new TotalSupplyDecimalsMock(18);
        AggregatorV3Mock feed = new AggregatorV3Mock(8, 1000 * 1e8);
        RuleChainlinkPoRERC3643 rule = new RuleChainlinkPoRERC3643(
            DEFAULT_ADMIN_ADDRESS, address(token), 18, AggregatorV3Interface(address(feed)), 1 days
        );
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleChainlinkPoRERC3643Ownable2Step() public {
        TotalSupplyDecimalsMock token = new TotalSupplyDecimalsMock(18);
        AggregatorV3Mock feed = new AggregatorV3Mock(8, 1000 * 1e8);
        RuleChainlinkPoRERC3643Ownable2Step rule = new RuleChainlinkPoRERC3643Ownable2Step(
            DEFAULT_ADMIN_ADDRESS, address(token), 18, AggregatorV3Interface(address(feed)), 1 days
        );
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleConditionalTransferLightMultiToken() public {
        RuleConditionalTransferLightMultiToken rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleMintAllowance() public {
        RuleMintAllowance rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    /**
     * @notice `IdentityRegistryWhitelist` is not a rule, but it is a deployable production contract
     *         wired into an ERC-3643 token's identity slot, so it carries the same version string.
     */
    function testVersionIdentityRegistryWhitelist() public {
        IdentityRegistryWhitelist registry = new IdentityRegistryWhitelist(DEFAULT_ADMIN_ADDRESS);
        assertEq(registry.version(), EXPECTED_VERSION);
    }
}
