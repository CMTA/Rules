// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ICMTATConstructor, CMTATStandalone} from "CMTATv3.0.0/deployment/CMTATStandalone.sol";
import {IRuleEngine} from "CMTATv3.0.0/interfaces/engine/IRuleEngine.sol";
import {ISnapshotEngine} from "CMTATv3.0.0/interfaces/engine/ISnapshotEngine.sol";
import {IERC1643} from "CMTATv3.0.0/interfaces/engine/IDocumentEngine.sol";
import {IERC1643CMTAT} from "CMTATv3.0.0/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";

/**
 * @title RuleChainlinkPoR with a RuleEngine set at CMTAT v3.0.0 deployment
 * @notice The rule needs the token address, so it cannot be passed in the token constructor itself; a
 * RuleEngine can, and binding the token last keeps every mint screened. The token reports 0 decimals; the
 * feed reports 1,000 tokens of reserves with 8 decimals.
 */
contract RuleChainlinkPoRV300DeploymentTest is Test, HelperContract {
    uint256 private constant RESERVES = 1000;
    uint256 private constant STALENESS = 1 days;

    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        AggregatorV3Mock feed = new AggregatorV3Mock(8, int256(RESERVES * 1e8));
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandalone token = new CMTATStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(
                IRuleEngine(address(engine)), ISnapshotEngine(ZERO_ADDRESS), IERC1643(ZERO_ADDRESS)
            )
        );
        RuleChainlinkPoR rule = new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), STALENESS
        );
        engine.addRule(IRule(address(rule)));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        engine.bindToken(address(token));
        (uint8 code, uint256 backed) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        assertEq(backed, RESERVES);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, RESERVES + 1), CODE_RESERVES_EXCEEDED);

        token.mint(ADDRESS1, RESERVES);
        vm.expectPartialRevert(RuleChainlinkPoR_InvalidTransfer.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(token.totalSupply(), RESERVES);
    }

    /// @notice The rule cannot be deployed before its token: the constructor requires a contract address.
    function testRuleCannotBeDeployedBeforeTheToken() public {
        AggregatorV3Mock feed = new AggregatorV3Mock(8, int256(RESERVES * 1e8));
        vm.expectRevert(RuleChainlinkPoR_TokenAddressZeroNotAllowed.selector);
        new RuleChainlinkPoR(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, 0, AggregatorV3Interface(address(feed)), STALENESS);
    }
}
