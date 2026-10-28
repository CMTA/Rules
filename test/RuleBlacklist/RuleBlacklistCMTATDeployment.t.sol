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

/**
 * @title RuleBlacklist set at CMTAT v3.3 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor. On v3.3 mint and burn
 * forward the minter / burner as `spender`, and the blacklist screens it (code 38).
 */
contract RuleBlacklistCMTATDeploymentTest is Test, HelperContract {
    RuleBlacklist private rule;
    address private constant MINTER = address(0x4D1);
    address private constant BURNER = address(0xB0B);

    function setUp() public {
        rule = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS3);
    }

    function _deployToken(address ruleEngine_) private returns (CMTATStandardStandalone token) {
        token = new CMTATStandardStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ruleEngine_))
        );
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        token.grantRole(keccak256("BURNER_ROLE"), BURNER);
        vm.stopPrank();
    }

    /// @notice Rule set directly in the constructor: the first mint is screened on the receiver, on the
    /// 4-argument path.
    function testRuleInConstructorScreensFirstMint() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));

        vm.startPrank(MINTER);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransferFrom.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();
        assertEq(token.balanceOf(ADDRESS1), 10);

        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS3, 1);
    }

    /// @notice A blacklisted minter cannot mint and a blacklisted burner cannot burn, even to or from
    /// clean addresses. The minter-aware pre-check is `canTransferFrom(minter, 0, to, value)`.
    function testBlacklistedMinterAndBurnerAreScreened() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 10), TRANSFER_OK);
        vm.prank(MINTER);
        token.mint(ADDRESS1, 10);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(MINTER);
        rule.addAddress(BURNER);
        vm.stopPrank();

        assertTrue(token.canTransfer(ZERO_ADDRESS, ADDRESS1, 10));
        assertFalse(token.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 10));
        assertEq(
            token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 10), CODE_ADDRESS_SPENDER_IS_BLACKLISTED
        );

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransferFrom.selector,
                address(rule),
                MINTER,
                ZERO_ADDRESS,
                ADDRESS1,
                10,
                CODE_ADDRESS_SPENDER_IS_BLACKLISTED
            )
        );
        token.mint(ADDRESS1, 10);

        vm.prank(BURNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransferFrom.selector,
                address(rule),
                BURNER,
                ADDRESS1,
                ZERO_ADDRESS,
                1,
                CODE_ADDRESS_SPENDER_IS_BLACKLISTED
            )
        );
        token.burn(ADDRESS1, 1);
    }

    /// @notice A blacklisted holder cannot be burned from; `forcedTransfer` skips the compliance call.
    function testBlacklistedHolderIsTrappedUntilForcedTransfer() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        vm.prank(MINTER);
        token.mint(ADDRESS1, 10);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);

        vm.prank(BURNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransferFrom.selector,
                address(rule),
                BURNER,
                ADDRESS1,
                ZERO_ADDRESS,
                1,
                CODE_ADDRESS_FROM_IS_BLACKLISTED
            )
        );
        token.burn(ADDRESS1, 1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.forcedTransfer(ADDRESS1, ADDRESS2, 10);
        assertEq(token.balanceOf(ADDRESS2), 10);
    }

    /// @notice RuleEngine in the constructor: nothing moves until the engine binds the token, then the
    /// engine forwards the minter to the rule.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(rule)));
        vm.stopPrank();
        CMTATStandardStandalone token = _deployToken(address(engine));

        vm.prank(MINTER);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 10);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        engine.bindToken(address(token));
        rule.addAddress(MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        vm.expectPartialRevert(RuleBlacklist_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddress(MINTER);
        vm.prank(MINTER);
        token.mint(ADDRESS1, 10);
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
