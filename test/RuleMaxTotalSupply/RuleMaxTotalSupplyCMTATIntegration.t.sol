// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {TokenBindingModuleInvariantStorage} from "RuleEngine/modules/library/TokenBindingModuleInvariantStorage.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";

/**
 * @title RuleMaxTotalSupply on the current CMTAT (>= v3.3)
 * @notice The two deployment orders the guide documents: the rule set directly on an existing token, and a
 * RuleEngine passed in the token constructor that binds the token last. Mints reach the rule on the
 * 4-argument path with the minter as spender, which the rule ignores.
 */
contract RuleMaxTotalSupplyCMTATIntegration is Test, HelperContract {
    uint256 private constant CAP = 100;
    address private constant MINTER = address(0x4D1);

    function _deployToken(address ruleEngine_) private returns (CMTATStandardStandalone) {
        return new CMTATStandardStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ruleEngine_))
        );
    }

    /// @notice The rule needs the token address, so it is deployed after the token and set with `setRuleEngine`.
    function testRuleSetDirectlyAfterDeployment() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        CMTATStandardStandalone token = _deployToken(ZERO_ADDRESS);
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        vm.stopPrank();

        vm.startPrank(MINTER);
        token.mint(ADDRESS1, 60);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 41), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 41);
        token.mint(ADDRESS2, 40);
        vm.stopPrank();
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, 0);

        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 60);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS2, 10);
        (, headroom) = rule.remainingMintable();
        assertEq(headroom, 10);
    }

    /// @notice RuleEngine in the constructor, rule deployed once the token exists, token bound last.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandardStandalone token = _deployToken(address(engine));
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        engine.addRule(IRule(address(rule)));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        engine.bindToken(address(token));
        token.mint(ADDRESS1, CAP);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(token.totalSupply(), CAP);
    }
}
