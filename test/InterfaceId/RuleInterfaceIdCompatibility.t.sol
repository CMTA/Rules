// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {BalanceOfMock} from "src/mocks/BalanceOfMock.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {TotalSupplyDecimalsMock} from "src/mocks/TotalSupplyDecimalsMock.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {
    RuleConditionalTransferLightOwnable2Step
} from "src/rules/operation/RuleConditionalTransferLightOwnable2Step.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {
    RuleConditionalTransferLightMultiTokenOwnable2Step
} from "src/rules/operation/RuleConditionalTransferLightMultiTokenOwnable2Step.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {RuleMintAllowanceOwnable2Step} from "src/rules/operation/RuleMintAllowanceOwnable2Step.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {RuleIssuanceCapOwnable2Step} from "src/rules/operation/RuleIssuanceCapOwnable2Step.sol";

/**
 * @notice RuleEngine v3.0.0-rc7 narrowed `IRule` (no `canTransfer` / `canTransferFrom`), changing its
 *         ERC-165 id. Every rule advertises both ids, so it is accepted by rc7 engines and by rc6 or older
 *         ones, which only know the legacy id. Covers each distinct `supportsInterface` implementation.
 */
contract RuleInterfaceIdCompatibilityTest is Test, HelperContract {
    bytes4 constant IRULE_ID = 0xb1a69752;
    bytes4 constant IRULE_LEGACY_ID = 0x2497d6cb;

    function testRuleInterfaceIdLiterals() public pure {
        assertEq(RuleInterfaceId.IRULE_INTERFACE_ID, IRULE_ID);
        assertEq(RuleInterfaceId.IRULE_LEGACY_INTERFACE_ID, IRULE_LEGACY_ID);
    }

    function testValidationRulesAdvertiseBothIds() public {
        _assertRuleIds(address(new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false)), "RuleWhitelist");
        _assertRuleIds(address(new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS)), "RuleBlacklist");
        _assertRuleIds(
            address(new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS))),
            "RuleSanctionsList"
        );
        _assertRuleIds(
            address(new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(new TotalSupplyMock()), 0)),
            "RuleMaxTotalSupply"
        );
        _assertRuleIds(
            address(new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, address(new BalanceOfMock()), 0)), "RuleMaxBalance"
        );
        _assertRuleIds(
            address(new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true)), "RuleWhitelistWrapper"
        );
        _assertRuleIds(address(new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false)), "RuleERC2980");
        _assertRuleIds(address(new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS)), "RuleSpenderWhitelist");
        _assertRuleIds(address(new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS)), "RuleReceiverWhitelist");
        _assertRuleIds(
            address(new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false)), "RuleIdentityRegistry"
        );
        _assertRuleIds(
            address(
                new RuleChainlinkPoR(
                    DEFAULT_ADMIN_ADDRESS,
                    address(new TotalSupplyDecimalsMock(18)),
                    18,
                    AggregatorV3Interface(address(new AggregatorV3Mock(8, 1000 * 1e8))),
                    1 days
                )
            ),
            "RuleChainlinkPoR"
        );
    }

    function testOperationRulesAdvertiseBothIds() public {
        _assertRuleIds(address(new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS)), "CTL");
        _assertRuleIds(address(new RuleConditionalTransferLightOwnable2Step(DEFAULT_ADMIN_ADDRESS)), "CTL 2Step");
        _assertRuleIds(address(new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS)), "CTL MultiToken");
        _assertRuleIds(
            address(new RuleConditionalTransferLightMultiTokenOwnable2Step(DEFAULT_ADMIN_ADDRESS)),
            "CTL MultiToken 2Step"
        );
        _assertRuleIds(address(new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS)), "RuleMintAllowance");
        _assertRuleIds(address(new RuleMintAllowanceOwnable2Step(DEFAULT_ADMIN_ADDRESS)), "RuleMintAllowance 2Step");
        _assertRuleIds(
            address(new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(new TotalSupplyMock()), 100, 0)),
            "RuleIssuanceCap"
        );
        _assertRuleIds(
            address(new RuleIssuanceCapOwnable2Step(DEFAULT_ADMIN_ADDRESS, address(new TotalSupplyMock()), 100, 0)),
            "RuleIssuanceCap 2Step"
        );
    }

    function _assertRuleIds(address rule, string memory name) internal view {
        IERC165 r = IERC165(rule);
        assertTrue(r.supportsInterface(IRULE_ID), string.concat(name, ": IRule"));
        assertTrue(r.supportsInterface(IRULE_LEGACY_ID), string.concat(name, ": legacy IRule"));
        // The standalone (Topology B) role still requires CMTAT's IRuleEngine.
        assertTrue(
            r.supportsInterface(RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID), string.concat(name, ": IRuleEngine")
        );
    }
}
