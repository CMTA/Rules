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
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";

/**
 * @title RuleWhitelistWrapper set at CMTAT v3.3 deployment
 * @notice The children are deployed and added first, then the wrapper (or a RuleEngine holding it) is passed
 * in the token constructor. One child is a `RuleWhitelist`, the other a `RuleReceiverWhitelist`: the wrapper
 * reads only their membership, so both parties are screened whichever child lists them.
 */
contract RuleWhitelistWrapperCMTATDeploymentTest is Test, HelperContract {
    address private constant MINTER = address(0x4D1);
    RuleWhitelistWrapper private wrapper;
    RuleWhitelist private childA;
    RuleReceiverWhitelist private childB;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        childA = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);
        childB = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        childA.addAddress(ADDRESS1);
        childB.addAddress(ADDRESS2);
        // checkSpender on: a transferFrom spender must be listed, the minter forwarded as spender must not.
        wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, true);
        wrapper.addRule(IRule(address(childA)));
        wrapper.addRule(IRule(address(childB)));
        vm.stopPrank();
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

    function _checkWrapperScreening(CMTATStandardStandalone token) private {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);

        vm.startPrank(MINTER);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransferFrom.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();

        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 4);
        assertEq(token.balanceOf(ADDRESS2), 4);

        // ADDRESS2 is listed only in the receiver-only child, yet counts as a listed sender for the wrapper.
        vm.prank(ADDRESS2);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS1, 1);
        assertEq(token.balanceOf(ADDRESS1), 7);

        // A receiver in no child is rejected.
        vm.prank(ADDRESS2);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS3, 1);

        vm.prank(ADDRESS1);
        token.approve(ADDRESS3, 1);
        assertEq(
            token.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 1), CODE_ADDRESS_SPENDER_NOT_WHITELISTED
        );
        vm.prank(ADDRESS3);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransferFrom.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(ADDRESS1, ADDRESS2, 1);
    }

    /// @notice Only allow-lists that declare their polarity are accepted as children.
    function testWrapperRefusesDenyListAndSpenderListChildren() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleBlacklist blacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        RuleSpenderWhitelist spenderList = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(RuleWhitelistWrapper_ChildIsNotAnAllowList.selector, blacklist));
        wrapper.addRule(IRule(address(blacklist)));
        vm.expectRevert(abi.encodeWithSelector(RuleWhitelistWrapper_ChildDoesNotDeclarePolarity.selector, spenderList));
        wrapper.addRule(IRule(address(spenderList)));
        vm.stopPrank();
        assertEq(wrapper.rulesCount(), 2);
    }

    /// @notice Wrapper set directly in the constructor.
    function testWrapperInConstructor() public {
        CMTATStandardStandalone token = _deployToken(address(wrapper));
        assertEq(address(token.ruleEngine()), address(wrapper));
        _checkWrapperScreening(token);
    }

    /// @notice RuleEngine in the constructor: nothing moves until the engine binds the token.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(wrapper)));
        CMTATStandardStandalone token = _deployToken(address(engine));
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 10);
        engine.bindToken(address(token));
        vm.stopPrank();
        _checkWrapperScreening(token);
    }
}
