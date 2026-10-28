// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";

/**
 * @title RuleMintAllowance against every CMTAT v3.3 operation
 * @notice Which caller each token operation charges: every path through the token's mint code forwards
 * `_msgSender()` as spender, so `crosschainMint` is charged to the bridge and the mint leg of `burnAndMint`
 * to its caller. Burns, forced transfers and plain transfers never touch a quota. Rule set directly on the
 * token and bound to it.
 */
contract RuleMintAllowanceCMTATOperationsTest is Test, HelperContract {
    address private constant MINTER = address(0x4D1);
    address private constant BRIDGE = address(0xB41D);
    uint256 private constant QUOTA = 100;

    CMTATStandardStandalone private token;
    RuleMintAllowance private rule;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        token = new CMTATStandardStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ZERO_ADDRESS))
        );
        rule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));
        token.grantRole(keccak256("MINTER_ROLE"), MINTER);
        token.grantRole(keccak256("BURNER_ROLE"), MINTER);
        token.grantRole(keccak256("CROSS_CHAIN_ROLE"), BRIDGE);
        rule.setMintAllowance(MINTER, QUOTA);
        rule.setMintAllowance(BRIDGE, QUOTA);
        vm.stopPrank();
    }

    /// @notice The bridge is the spender of `crosschainMint`: its own quota is debited and enforced.
    function testCrosschainMintIsChargedToTheBridge() public {
        vm.prank(BRIDGE);
        token.crosschainMint(ADDRESS1, 60);
        assertEq(rule.mintAllowance(BRIDGE), QUOTA - 60);
        assertEq(rule.mintAllowance(MINTER), QUOTA, "minter untouched");

        vm.prank(BRIDGE);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMintAllowance_AllowanceExceeded.selector, address(rule), BRIDGE, QUOTA - 60, QUOTA - 59
            )
        );
        token.crosschainMint(ADDRESS1, QUOTA - 59);
    }

    /// @notice `crosschainBurn` frees nothing and charges nothing: the quota counts issuance only.
    function testCrosschainBurnDoesNotRestoreTheQuota() public {
        vm.prank(BRIDGE);
        token.crosschainMint(ADDRESS1, 60);
        vm.prank(ADDRESS1);
        token.approve(BRIDGE, 60);
        vm.prank(BRIDGE);
        token.crosschainBurn(ADDRESS1, 60);
        assertEq(rule.mintAllowance(BRIDGE), QUOTA - 60);
    }

    /// @notice Only the mint leg of `burnAndMint` is charged, to the caller, for the full minted amount.
    function testBurnAndMintChargesTheMintLegOnly() public {
        vm.startPrank(MINTER);
        token.mint(ADDRESS1, 50);
        token.burnAndMint(ADDRESS1, ADDRESS2, 50, 30, "");
        vm.stopPrank();
        assertEq(rule.mintAllowance(MINTER), QUOTA - 80);
        assertEq(token.balanceOf(ADDRESS2), 30);

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(RuleMintAllowance_AllowanceExceeded.selector, address(rule), MINTER, 20, 21)
        );
        token.burnAndMint(ADDRESS2, ADDRESS1, 0, 21, "");
    }

    /// @notice A `batchMint` is charged once per recipient, and fails as a whole when the quota runs out.
    function testBatchMintIsChargedInTotal() public {
        address[] memory to = new address[](2);
        to[0] = ADDRESS1;
        to[1] = ADDRESS2;
        uint256[] memory values = new uint256[](2);
        values[0] = 40;
        values[1] = 40;
        vm.prank(MINTER);
        token.batchMint(to, values);
        assertEq(rule.mintAllowance(MINTER), QUOTA - 80);

        values[1] = 1;
        vm.prank(MINTER);
        vm.expectRevert();
        token.batchMint(to, values);
        assertEq(rule.mintAllowance(MINTER), QUOTA - 80, "rolled back");
    }

    /// @notice Burns, forced transfers, transfers and `transferFrom` never touch a quota.
    function testNonMintOperationsAreNotCharged() public {
        vm.prank(MINTER);
        token.mint(ADDRESS1, 50);

        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(ADDRESS2, 10);
        vm.prank(ADDRESS1);
        token.approve(MINTER, 10);
        vm.prank(MINTER);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(ADDRESS1, ADDRESS2, 10);
        vm.prank(MINTER);
        token.burn(ADDRESS2, 5);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.forcedTransfer(ADDRESS1, ADDRESS3, 5);

        assertEq(rule.mintAllowance(MINTER), QUOTA - 50);
        assertEq(token.totalSupply(), 45);
    }

    /// @notice Unbinding and rebinding keeps every quota: `unbindToken` clears no state.
    function testQuotasSurviveUnbindAndRebind() public {
        vm.prank(MINTER);
        token.mint(ADDRESS1, 30);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.unbindToken(address(token));
        vm.stopPrank();

        // Unbound: the token's own call is refused, so nothing can be minted.
        vm.prank(MINTER);
        vm.expectRevert();
        token.mint(ADDRESS1, 1);
        assertEq(token.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 1), CODE_RULE_NOT_BOUND);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(token));
        assertEq(rule.mintAllowance(MINTER), QUOTA - 30);
        vm.prank(MINTER);
        token.mint(ADDRESS1, QUOTA - 30);
        assertEq(rule.mintAllowance(MINTER), 0);
    }

    /// @notice The Debt variant shares the mint path: the quota is enforced there too.
    function testDebtVariantEnforcesTheQuota() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        CMTATStandaloneDebt debt = new CMTATStandaloneDebt(
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Debt", "CMTAD", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ZERO_ADDRESS))
        );
        RuleMintAllowance debtRule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);
        debtRule.bindToken(address(debt));
        debt.setRuleEngine(IRuleEngine(address(debtRule)));
        debt.grantRole(keccak256("MINTER_ROLE"), MINTER);
        debtRule.setMintAllowance(MINTER, QUOTA);
        vm.stopPrank();

        assertFalse(debt.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, QUOTA + 1));
        vm.prank(MINTER);
        debt.mint(ADDRESS1, QUOTA);
        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(RuleMintAllowance_AllowanceExceeded.selector, address(debtRule), MINTER, 0, 1)
        );
        debt.mint(ADDRESS1, 1);
    }
}
