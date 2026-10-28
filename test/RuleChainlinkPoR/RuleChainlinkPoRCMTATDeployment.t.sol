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
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";

/**
 * @title RuleChainlinkPoR on the current CMTAT (>= v3.3): deployment orders
 * @notice The rule set directly on an existing token, and a RuleEngine passed in the token constructor that
 * binds the token last. Mints reach the rule on the 4-argument path with the minter as spender, which the rule
 * ignores. The token reports 0 decimals; the feed reports 1,000 tokens of reserves with 8 decimals.
 */
contract RuleChainlinkPoRCMTATDeployment is Test, HelperContract {
    uint256 private constant RESERVES = 1000;
    uint256 private constant STALENESS = 1 days;
    address private constant MINTER = address(0x4D1);

    AggregatorV3Mock private feed;

    function setUp() public {
        feed = new AggregatorV3Mock(8, int256(RESERVES * 1e8));
    }

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

    function _deployRule(address token) private returns (RuleChainlinkPoR) {
        return new RuleChainlinkPoR(DEFAULT_ADMIN_ADDRESS, token, 0, AggregatorV3Interface(address(feed)), STALENESS);
    }

    /// @notice The rule needs the token address, so it is deployed after the token and set with `setRuleEngine`.
    function testRuleSetDirectlyAfterDeployment() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        CMTATStandardStandalone token = _deployToken(ZERO_ADDRESS);
        RuleChainlinkPoR rule = _deployRule(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        vm.stopPrank();

        vm.startPrank(MINTER);
        token.mint(ADDRESS1, 600);
        assertEq(token.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 401), CODE_RESERVES_EXCEEDED);
        vm.expectPartialRevert(RuleChainlinkPoR_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 401);
        token.mint(ADDRESS2, 400);
        vm.stopPrank();
        assertEq(token.totalSupply(), RESERVES);

        // A stale feed blocks mints only: transfers and burns still pass.
        vm.warp(block.timestamp + STALENESS + 1);
        (uint8 code,) = rule.maxBackedSupply();
        assertEq(code, CODE_RESERVES_FEED_STALE);
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 100);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS2, 10);
        vm.prank(MINTER);
        vm.expectPartialRevert(RuleChainlinkPoR_InvalidTransferFrom.selector);
        token.mint(ADDRESS2, 1);
    }

    /// @notice RuleEngine in the constructor, rule deployed once the token exists, token bound last.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        CMTATStandardStandalone token = _deployToken(address(engine));
        RuleChainlinkPoR rule = _deployRule(address(token));
        engine.addRule(IRule(address(rule)));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 1);

        engine.bindToken(address(token));
        token.mint(ADDRESS1, RESERVES);
        vm.expectPartialRevert(RuleChainlinkPoR_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 1);
        vm.stopPrank();
        assertEq(token.totalSupply(), RESERVES);
    }

    /// @notice The token reports its decimals, so the rule refuses a value that does not match them.
    function testRuleRefusesMismatchedTokenDecimals() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTATStandardStandalone token = _deployToken(ZERO_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(RuleChainlinkPoR_TokenDecimalsMismatch.selector, 18, 0));
        new RuleChainlinkPoR(DEFAULT_ADMIN_ADDRESS, address(token), 18, AggregatorV3Interface(address(feed)), STALENESS);
    }
}
