// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {
    RuleMaxBalanceInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxBalanceInvariantStorage.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";

/**
 * @notice End-to-end: the cap enforced by a real CMTAT token through a RuleEngine.
 * @dev Two things are worth proving against a real token rather than a mock. First, the rule reads
 *      `balanceOf` from the token it is configured with, so the balance it sees is the one the token
 *      is about to change. Second, the documented mitigation actually mitigates: the last test pairs
 *      the cap with `RuleWhitelist` and shows the split-wallet bypass is only closed by the operator
 *      admitting one address per investor -- the whitelist alone does not close it.
 */
contract RuleMaxBalanceCMTATIntegration is Test, HelperContract, RuleMaxBalanceInvariantStorage {
    uint256 constant CAP = 1000;

    RuleEngine private ruleEngine;
    RuleMaxBalance private rule;

    address constant INVESTOR = address(0x101);
    address constant INVESTOR_SECOND_WALLET = address(0x102);
    address constant CUSTODIAN = address(0x103);
    address constant OTHER = address(0x104);

    function setUp() public {
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, address(cmtatContract), CAP);
        ruleEngine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
        ruleEngine.addRule(rule);
        cmtatContract.setRuleEngine(ruleEngine);
        vm.stopPrank();
    }

    function testMintUpToTheCapSucceeds() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, CAP);
        assertEq(cmtatContract.balanceOf(INVESTOR), CAP);
    }

    /**
     * @notice Pins the pre-update accounting the whole check depends on.
     * @dev The rule compares `balanceOf(to) + value` against the cap, which is only correct while
     *      `balanceOf(to)` still excludes `value`. CMTAT calls `_checkTransferred(...)` before
     *      `ERC20Upgradeable._transfer(...)`, so it does. If a token ever notified compliance
     *      *after* updating balances, this mint of exactly the cap would be seen as `CAP + CAP` and
     *      rejected -- the effective cap would silently halve. This test is the alarm for that.
     */
    function testMintExactlyToTheCapProvesPreUpdateAccounting() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, CAP);
        assertEq(cmtatContract.balanceOf(INVESTOR), CAP, "a mint of exactly the cap must succeed");

        // And the boundary is exact: one more unit is rejected.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert();
        cmtatContract.mint(INVESTOR, 1);
    }

    function testMintPastTheCapIsBlocked() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, CAP);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert();
        cmtatContract.mint(INVESTOR, 1);
    }

    function testTransferThatWouldBreachTheCapIsBlocked() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, CAP);
        cmtatContract.mint(OTHER, CAP);
        vm.stopPrank();

        // OTHER is already at the cap, so it cannot receive anything more.
        vm.prank(INVESTOR);
        vm.expectRevert();
        cmtatContract.transfer(OTHER, 1);
    }

    function testSendingDownFreesHeadroom() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, CAP);

        vm.prank(INVESTOR);
        cmtatContract.transfer(OTHER, 400);

        // INVESTOR is now 400 under the cap and can receive again.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, 400);
        assertEq(cmtatContract.balanceOf(INVESTOR), CAP);
    }

    function testExemptCustodianMayExceedTheCap() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addExemptAddress(CUSTODIAN);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(CUSTODIAN, CAP * 10);
        assertEq(cmtatContract.balanceOf(CUSTODIAN), CAP * 10);
    }

    function testBurningIsNeverBlocked() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(INVESTOR, CAP);
        cmtatContract.burn(INVESTOR, CAP, "");
        vm.stopPrank();
        assertEq(cmtatContract.balanceOf(INVESTOR), 0);
    }

    /**
     * @notice The documented limitation, end to end: one investor, two wallets, twice the cap.
     * @dev Adding `RuleWhitelist` does **not** by itself close this -- the whitelist admits
     *      addresses, and if the operator admits both of an investor's wallets the cap is still
     *      doubled. The mitigation is the operator policy of one admitted address per investor,
     *      which is what the rule documentation requires. This test pins the exposure so the
     *      documentation cannot quietly drift away from the behaviour.
     */
    function testSplitWalletsBypassTheCapEvenWithAWhitelist() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist whitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        // The operator admits BOTH wallets of the same investor -- the policy failure.
        whitelist.addAddress(INVESTOR);
        whitelist.addAddress(INVESTOR_SECOND_WALLET);
        ruleEngine.addRule(whitelist);

        cmtatContract.mint(INVESTOR, CAP);
        cmtatContract.mint(INVESTOR_SECOND_WALLET, CAP);
        vm.stopPrank();

        // Same person, 2x the cap, no rule objected.
        assertEq(cmtatContract.balanceOf(INVESTOR) + cmtatContract.balanceOf(INVESTOR_SECOND_WALLET), CAP * 2);
    }
}
