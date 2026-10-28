// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";

/**
 * @title End-to-end integration test: CMTAT + RuleEngine + RuleMintAllowance
 * @notice Verifies that the mint allowance is enforced through the full CMTAT call chain.
 *         In CMTAT v3.3+ the minter address is passed as `spender` when the rule engine
 *         calls `transferred(spender, address(0), to, value)`.
 */
contract CMTATIntegration is Test, HelperContract {
    address constant MINTER = address(10);

    RuleMintAllowance private mintAllowanceRule;

    function setUp() public {
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule = new RuleMintAllowance(DEFAULT_ADMIN_ADDRESS);

        // Bind the rule to the RuleEngine (the entity that calls transferred() on the rule)
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.bindToken(address(ruleEngineMock));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(mintAllowanceRule);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);

        // Grant minter role on CMTAT to MINTER
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);
    }

    function testMintSucceedsWithSufficientAllowance() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 500);

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 300);

        assertEq(cmtatContract.balanceOf(ADDRESS1), 300);
        assertEq(mintAllowanceRule.mintAllowance(MINTER), 200);
    }

    function testMintRevertsWhenAllowanceExceeded() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 100);

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMintAllowance_AllowanceExceeded.selector, address(mintAllowanceRule), MINTER, 100, 101
            )
        );
        cmtatContract.mint(ADDRESS1, 101);
    }

    function testMintRevertsWithZeroAllowance() public {
        // Default allowance is 0
        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, 1);
    }

    function testBatchMintSucceedsWithinCumulativeAllowance() public {
        address[] memory accounts = new address[](2);
        accounts[0] = ADDRESS1;
        accounts[1] = ADDRESS2;

        uint256[] memory values = new uint256[](2);
        values[0] = 300;
        values[1] = 200;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 500);

        vm.prank(MINTER);
        cmtatContract.batchMint(accounts, values);

        assertEq(cmtatContract.balanceOf(ADDRESS1), 300);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 200);
        assertEq(mintAllowanceRule.mintAllowance(MINTER), 0);
    }

    function testBatchMintRevertsAndRollsBackWhenCumulativeAllowanceExceeded() public {
        address[] memory accounts = new address[](2);
        accounts[0] = ADDRESS1;
        accounts[1] = ADDRESS2;

        uint256[] memory values = new uint256[](2);
        values[0] = 300;
        values[1] = 201;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 500);

        vm.prank(MINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleMintAllowance_AllowanceExceeded.selector, address(mintAllowanceRule), MINTER, 200, 201
            )
        );
        cmtatContract.batchMint(accounts, values);

        assertEq(cmtatContract.balanceOf(ADDRESS1), 0);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 0);
        assertEq(mintAllowanceRule.mintAllowance(MINTER), 500);
    }

    function testMultipleMintersSeparateAllowances() public {
        address minter2 = address(11);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), minter2);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 500);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(minter2, 200);

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 500);
        vm.prank(minter2);
        cmtatContract.mint(ADDRESS2, 200);

        assertEq(mintAllowanceRule.mintAllowance(MINTER), 0);
        assertEq(mintAllowanceRule.mintAllowance(minter2), 0);
        assertEq(cmtatContract.balanceOf(ADDRESS1), 500);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 200);
    }

    function testDetectTransferRestrictionFromViaCMTAT() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 100);

        // Sufficient allowance
        assertEq(cmtatContract.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 100), TRANSFER_OK);
        assertTrue(cmtatContract.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 100));

        // Exceeds allowance
        assertEq(
            cmtatContract.detectTransferRestrictionFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 101),
            CODE_MINTER_ALLOWANCE_EXCEEDED
        );
        assertFalse(cmtatContract.canTransferFrom(MINTER, ZERO_ADDRESS, ADDRESS1, 101));
    }

    function testRegularTransfersAreNotRestricted() public {
        // Set up balances via admin mint (admin has unlimited system-level access before rule kicks in)
        // We need to give admin an allowance to mint first
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(DEFAULT_ADMIN_ADDRESS, 1000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 500);

        // Regular transfer should not be restricted by mint allowance rule
        assertTrue(cmtatContract.canTransfer(ADDRESS1, ADDRESS2, 100));
        assertEq(cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 100), TRANSFER_OK);

        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, 100);
        assertEq(cmtatContract.balanceOf(ADDRESS2), 100);
    }

    function testAllowanceCanBeIncreasedAfterExhaustion() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.setMintAllowance(MINTER, 100);

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 100);
        assertEq(mintAllowanceRule.mintAllowance(MINTER), 0);

        // Next mint fails
        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, 1);

        // Operator increases allowance
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        mintAllowanceRule.increaseMintAllowance(MINTER, 50);
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, 50);
        assertEq(mintAllowanceRule.mintAllowance(MINTER), 0);
    }
}
