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
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";

/**
 * @title RuleSanctionsList set at CMTAT v3.3 deployment
 * @notice The rule (or a RuleEngine holding it) passed in the token constructor, with the oracle set in
 * the rule constructor. On v3.3 the minter / burner arrives as `spender` and is screened (code 32).
 */
contract RuleSanctionsListCMTATDeploymentTest is Test, HelperContract {
    SanctionListOracle private oracle;
    RuleSanctionsList private rule;
    address private constant MINTER = address(0x4D1);
    address private constant BURNER = address(0xB0B);

    function setUp() public {
        oracle = new SanctionListOracle();
        oracle.addToSanctionsList(ADDRESS3);
        rule = new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(address(oracle)));
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

    /// @notice Rule set directly in the constructor: the first mint is screened on the receiver.
    function testRuleInConstructorScreensFirstMint() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(address(token.ruleEngine()), address(rule));

        vm.startPrank(MINTER);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransferFrom.selector);
        token.mint(ADDRESS3, 10);
        token.mint(ADDRESS1, 10);
        vm.stopPrank();

        vm.prank(ADDRESS1);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransfer.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS3, 1);
    }

    /// @notice A sanctioned minter cannot mint and a sanctioned burner cannot burn.
    function testSanctionedMinterAndBurnerAreScreened() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        assertEq(token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 10), TRANSFER_OK);
        vm.prank(MINTER);
        token.mint(ADDRESS1, 10);
        oracle.addToSanctionsList(MINTER);
        oracle.addToSanctionsList(BURNER);

        assertTrue(token.canTransfer(ZERO_ADDRESS, ADDRESS1, 10));
        assertFalse(token.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 10));
        assertEq(
            token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 10), CODE_ADDRESS_SPENDER_IS_SANCTIONED
        );

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleSanctionsList_InvalidTransferFrom.selector,
                address(rule),
                MINTER,
                ZERO_ADDRESS,
                ADDRESS1,
                10,
                CODE_ADDRESS_SPENDER_IS_SANCTIONED
            )
        );
        token.mint(ADDRESS1, 10);

        vm.prank(BURNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleSanctionsList_InvalidTransferFrom.selector,
                address(rule),
                BURNER,
                ADDRESS1,
                ZERO_ADDRESS,
                1,
                CODE_ADDRESS_SPENDER_IS_SANCTIONED
            )
        );
        token.burn(ADDRESS1, 1);
    }

    /// @notice A rule deployed without an oracle fails open, and `clearSanctionListOracle` reopens it.
    function testRuleWithoutOracleFailsOpen() public {
        RuleSanctionsList bare =
            new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS));
        CMTATStandardStandalone token = _deployToken(address(bare));

        vm.prank(MINTER);
        token.mint(ADDRESS3, 10);
        assertEq(token.balanceOf(ADDRESS3), 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        bare.setSanctionListOracle(ISanctionsList(address(oracle)));
        vm.prank(MINTER);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransferFrom.selector);
        token.mint(ADDRESS3, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        bare.clearSanctionListOracle();
        vm.prank(MINTER);
        token.mint(ADDRESS3, 10);
        assertEq(token.balanceOf(ADDRESS3), 20);
    }

    /// @notice The setter does not check that the oracle has code: an address without code makes every
    /// screened operation revert, and the token's views revert too.
    function testOracleWithoutCodeRevertsEveryOperation() public {
        CMTATStandardStandalone token = _deployToken(address(rule));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setSanctionListOracle(ISanctionsList(address(0xDEAD)));

        vm.prank(MINTER);
        vm.expectRevert();
        token.mint(ADDRESS1, 10);

        vm.expectRevert();
        token.canTransfer(ADDRESS1, ADDRESS2, 1);
    }

    /// @notice RuleEngine in the constructor: nothing moves until the engine binds the token.
    function testRuleEngineInConstructorBlocksUntilTokenBound() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleEngine engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        engine.addRule(IRule(address(rule)));
        vm.stopPrank();
        CMTATStandardStandalone token = _deployToken(address(engine));

        vm.prank(MINTER);
        vm.expectRevert(TokenBindingModuleInvariantStorage.TokenBinding_UnauthorizedCaller.selector);
        token.mint(ADDRESS1, 10);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        engine.bindToken(address(token));
        oracle.addToSanctionsList(MINTER);
        vm.prank(MINTER);
        vm.expectPartialRevert(RuleSanctionsList_InvalidTransferFrom.selector);
        token.mint(ADDRESS1, 10);

        oracle.removeFromSanctionsList(MINTER);
        vm.prank(MINTER);
        token.mint(ADDRESS1, 10);
        assertEq(token.balanceOf(ADDRESS1), 10);
    }
}
