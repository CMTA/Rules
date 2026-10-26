// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";

/**
 * @title RuleIssuanceCap on CMTAT v3.0.0
 * @notice The setup of CMTA/Rules#16: a per-token cap on cumulative issuance, driven by the 3-argument mint
 * path of v3.0.0. Burns never restore room. The rule is bound to the token (direct) or to the RuleEngine.
 */
abstract contract RuleIssuanceCapV300Test is CMTATv300TestBase {
    uint8 constant CODE_ISSUANCE_CAP = 71;
    uint256 constant CAP = 100;
    RuleIssuanceCap internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleIssuanceCap(DEFAULT_ADMIN_ADDRESS, address(token), CAP, 0);
        _attach(address(rule));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(_ruleCaller());
        _mint(ADDRESS1, 60);
    }

    function testMintsAreCounted() public view {
        assertEq(rule.totalIssued(), 60);
        (, uint256 headroom) = rule.remainingMintable();
        assertEq(headroom, 40);
    }

    function testBurnDoesNotRestoreTheCap() public {
        _burn(ADDRESS1, 30); // supply 30, issued 60
        _assertCode(ZERO_ADDRESS, ADDRESS2, 41, CODE_ISSUANCE_CAP);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 41);
        _mint(ADDRESS2, 40);
        assertEq(rule.totalIssued(), CAP);
        assertEq(token.totalSupply(), 70);
    }

    function testForcedBurnDoesNotRestoreTheCap() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.forcedTransfer(ADDRESS1, ZERO_ADDRESS, 30);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 41);
    }

    /// @notice The mint leg of `burnAndMint` is new issuance in full; the burn leg restores nothing.
    function testBurnAndMintCountsTheMintLegInFull() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burnAndMint(ADDRESS1, ADDRESS2, 30, 40, "");
        assertEq(rule.totalIssued(), CAP);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        token.burnAndMint(ADDRESS1, ADDRESS2, 10, 1, "");
    }

    /// @notice Standard only: a bridge round trip uses up the cap (bridge-in is counted as issuance).
    function testBridgeRoundTripUsesUpTheCap() public {
        if (_isDebt()) {
            return;
        }
        _approve(ADDRESS1, DEFAULT_ADMIN_ADDRESS, 30);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        token.crosschainBurn(ADDRESS1, 30);
        token.crosschainMint(ADDRESS1, 30);
        vm.stopPrank();
        assertEq(token.totalSupply(), 60);
        assertEq(rule.totalIssued(), 90);
    }

    function testTransfersAreNotCounted() public {
        _transfer(ADDRESS1, ADDRESS2, 10);
        _transferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10);
        assertEq(rule.totalIssued(), 60);
    }

    /// @notice Mints made while detached are missed by the counter but caught by the live-supply leg.
    function testMintsWhileDetachedAreCaughtByTheLiveLeg() public {
        _detach();
        _mint(ADDRESS2, 50); // supply 110, counter still 60
        _reattach(_viaEngine() ? address(engine) : address(rule));
        _assertCode(ZERO_ADDRESS, ADDRESS2, 1, CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 1);
    }

    function testLoweringTheCapFreezesMintingOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(60);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 1);
        _transfer(ADDRESS1, ADDRESS2, 10);
        _burn(ADDRESS1, 10);
    }
}

contract RuleIssuanceCapV300StandardDirectTest is RuleIssuanceCapV300Test, V300StandardDirect {}

contract RuleIssuanceCapV300StandardEngineTest is RuleIssuanceCapV300Test, V300StandardEngine {}

contract RuleIssuanceCapV300DebtDirectTest is RuleIssuanceCapV300Test, V300DebtDirect {}

contract RuleIssuanceCapV300DebtEngineTest is RuleIssuanceCapV300Test, V300DebtEngine {}
