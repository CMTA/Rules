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
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";

/**
 * @title RuleWhitelistWrapper set at CMTAT v3.0.0 deployment
 * @notice The children are deployed and added first, then the wrapper (or a RuleEngine holding it) is passed
 * in the token constructor. The children are built with mint and burn disabled: only the wrapper's own
 * flags apply, since the wrapper asks its children for list membership only.
 */
contract RuleWhitelistWrapperV300DeploymentTest is Test, HelperContract {
    RuleWhitelistWrapper private wrapper;
    RuleWhitelist private childA;
    RuleWhitelist private childB;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        childA = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);
        childB = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);
        childA.addAddress(ADDRESS1);
        childB.addAddress(ADDRESS2);
        wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        wrapper.addRule(IRule(address(childA)));
        wrapper.addRule(IRule(address(childB)));
        vm.stopPrank();
    }

    function _deployToken(address ruleEngine_) private returns (CMTATStandalone) {
        return new CMTATStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ruleEngine_), ISnapshotEngine(ZERO_ADDRESS), IERC1643(ZERO_ADDRESS))
        );
    }

    /// @notice Wrapper set directly in the constructor: the first mint is screened, and an address listed in
    /// one child can transfer to an address listed in another.
    function testWrapperInConstructorScreensFirstMint() public {
        CMTATStandalone token = _deployToken(address(wrapper));
        assertEq(address(token.ruleEngine()), address(wrapper));

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();

        assertEq(token.detectTransferRestriction(ADDRESS1, ADDRESS3, 1), CODE_ADDRESS_TO_NOT_WHITELISTED);
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 4);
        assertEq(token.balanceOf(ADDRESS2), 4);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(ADDRESS2, 4);
        assertEq(token.totalSupply(), 6);
    }

    /// @notice RuleEngine in the constructor: nothing moves until the engine binds the token.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(wrapper)));
        CMTATStandalone token = _deployToken(address(engine));

        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 10);

        engine.bindToken(address(token));
        vm.expectPartialRevert(RuleWhitelist_InvalidTransfer.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 4);
        assertEq(token.balanceOf(ADDRESS2), 4);
    }
}
