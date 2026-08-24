// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {
    ERC3643ChainlinkPoRHarness,
    ERC3643MaxBalanceHarness,
    ERC3643MaxTotalSupplyHarness,
    TrackedSupplyHarness
} from "src/mocks/harness/ERC3643CapHarnesses.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {BalanceOfMock} from "src/mocks/BalanceOfMock.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";

/**
 * @title ERC3643CapSeams
 * @notice Proves the two seams the cap rules expose are sufficient to build an ERC-3643 variant,
 *         without changing what the stock (CMTAT) rules do.
 * @dev The three cap rules assume the token calls them BEFORE moving the value, so the observation
 *      still excludes it. ERC-3643 / T-REX calls AFTER — `Token.transfer` runs `_transfer` then
 *      `_tokenCompliance.transferred`, and `mint` runs `_mint` then `created` — so the observation
 *      already includes it and the stock rule counts it twice, rejecting transfers that are within
 *      the cap (Nethermind AuditAgent NM-11).
 *
 *      Each test below simulates both call orders against the same cap and asserts:
 *        - the stock rule is correct pre-update and double-counts post-update;
 *        - the harness, which overrides one hook, is correct post-update;
 *        - neither rule ever admits anything ABOVE the cap.
 */
contract ERC3643CapSeams is Test, HelperContract {
    uint256 private constant CAP = 1000;

    /*//////////////////////////////////////////////////////////////
                    SEAM 1 — MAX TOTAL SUPPLY
    //////////////////////////////////////////////////////////////*/

    function testMaxTotalSupply_StockRuleDoubleCountsUnderPostUpdateAccounting() public {
        TotalSupplyMock token = new TotalSupplyMock();
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);

        // Pre-update (CMTAT): supply still 0 when the rule is called. A mint of exactly the cap fits.
        token.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP), TRANSFER_OK);

        // Post-update (T-REX): the mint already landed, so totalSupply == CAP when the rule is called.
        // The stock rule adds CAP again and rejects a mint that exactly fills the cap.
        token.setTotalSupply(CAP);
        assertEq(
            rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED,
            "NM-11: the stock rule counts the value twice on a post-update token"
        );
    }

    function testMaxTotalSupply_Erc3643HarnessIsCorrectUnderPostUpdateAccounting() public {
        TotalSupplyMock token = new TotalSupplyMock();
        ERC3643MaxTotalSupplyHarness rule = new ERC3643MaxTotalSupplyHarness(DEFAULT_ADMIN_ADDRESS, address(token), CAP);

        // A mint that exactly fills the cap: post-mint supply == CAP, which is allowed.
        token.setTotalSupply(CAP);
        vm.prank(address(token));
        rule.transferred(ZERO_ADDRESS, ADDRESS1, CAP);

        // One unit more: post-mint supply == CAP + 1, which is not.
        token.setTotalSupply(CAP + 1);
        vm.prank(address(token));
        vm.expectRevert();
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testMaxTotalSupply_PreFlightViewStillCountsTheValue() public {
        // The read path must NOT be re-phased: a pre-flight query always runs before the movement,
        // on either kind of token, so it still has to add `value`.
        TotalSupplyMock token = new TotalSupplyMock();
        ERC3643MaxTotalSupplyHarness rule = new ERC3643MaxTotalSupplyHarness(DEFAULT_ADMIN_ADDRESS, address(token), CAP);

        token.setTotalSupply(CAP);
        assertEq(
            rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1),
            CODE_MAX_TOTAL_SUPPLY_EXCEEDED,
            "pre-flight must still project the pending value"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        SEAM 1 — MAX BALANCE
    //////////////////////////////////////////////////////////////*/

    function testMaxBalance_StockRuleDoubleCountsUnderPostUpdateAccounting() public {
        BalanceOfMock token = new BalanceOfMock();
        RuleMaxBalance rule = new RuleMaxBalance(DEFAULT_ADMIN_ADDRESS, address(token), CAP);

        token.setBalance(ADDRESS1, 0);
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS1, CAP), TRANSFER_OK);

        token.setBalance(ADDRESS1, CAP);
        assertEq(
            rule.detectTransferRestriction(ADDRESS2, ADDRESS1, CAP),
            rule.CODE_MAX_BALANCE_EXCEEDED(),
            "NM-11: the stock rule counts the value twice on a post-update token"
        );
    }

    function testMaxBalance_Erc3643HarnessIsCorrectUnderPostUpdateAccounting() public {
        BalanceOfMock token = new BalanceOfMock();
        ERC3643MaxBalanceHarness rule = new ERC3643MaxBalanceHarness(DEFAULT_ADMIN_ADDRESS, address(token), CAP);

        token.setBalance(ADDRESS1, CAP);
        vm.prank(address(token));
        rule.transferred(ADDRESS2, ADDRESS1, CAP);

        token.setBalance(ADDRESS1, CAP + 1);
        vm.prank(address(token));
        vm.expectRevert();
        rule.transferred(ADDRESS2, ADDRESS1, 1);
    }

    /*//////////////////////////////////////////////////////////////
                      SEAM 1 — CHAINLINK PROOF OF RESERVE
    //////////////////////////////////////////////////////////////*/

    function testChainlinkPoR_Erc3643HarnessIsCorrectUnderPostUpdateAccounting() public {
        TotalSupplyMock token = new TotalSupplyMock();
        AggregatorV3Mock feed = new AggregatorV3Mock(0, int256(CAP));

        RuleChainlinkPoR stock =
            new RuleChainlinkPoR(DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), 0);
        ERC3643ChainlinkPoRHarness harness = new ERC3643ChainlinkPoRHarness(
            DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), 0
        );

        // Reserves back exactly CAP. Post-mint supply is CAP, so the mint is fully backed.
        token.setTotalSupply(CAP);
        assertEq(
            stock.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP),
            CODE_RESERVES_EXCEEDED,
            "NM-11: the stock rule counts the minted value twice against the reserves"
        );
        vm.prank(address(token));
        harness.transferred(ZERO_ADDRESS, ADDRESS1, CAP);

        // Minting past the reserves is still rejected by the harness.
        token.setTotalSupply(CAP + 1);
        vm.prank(address(token));
        vm.expectRevert();
        harness.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    SEAM 2 — OBSERVATION SOURCE
    //////////////////////////////////////////////////////////////*/

    function testTrackedSupply_ObservationCanComeFromTheRuleInsteadOfTheToken() public {
        TotalSupplyMock token = new TotalSupplyMock();
        TrackedSupplyHarness rule = new TrackedSupplyHarness(DEFAULT_ADMIN_ADDRESS, address(token), CAP);

        // The token reports a supply the rule must ignore entirely.
        token.setTotalSupply(type(uint256).max);

        rule.setTrackedSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP), TRANSFER_OK);

        rule.setTrackedSupply(CAP);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
    }
}
