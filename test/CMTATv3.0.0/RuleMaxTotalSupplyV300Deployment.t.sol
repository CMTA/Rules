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
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";

/**
 * @title RuleMaxTotalSupply with a RuleEngine set at CMTAT v3.0.0 deployment
 * @notice The rule needs the token address, so it cannot be passed in the token constructor itself; a
 * RuleEngine can, and binding the token last keeps every mint screened.
 */
contract RuleMaxTotalSupplyV300DeploymentTest is Test, HelperContract {
    uint256 private constant CAP = 100;

    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
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
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        engine.addRule(IRule(address(rule)));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        engine.bindToken(address(token));
        token.mint(ADDRESS1, CAP);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(token.totalSupply(), CAP);
    }

    /// @notice The rule cannot be deployed before its token: the constructor requires a contract address.
    function testRuleCannotBeDeployedBeforeTheToken() public {
        vm.expectRevert(RuleMaxTotalSupply_TokenAddressZeroNotAllowed.selector);
        new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, CAP);
    }
}
