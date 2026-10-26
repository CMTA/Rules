// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";
import {V300StandardDirect, V300StandardEngine, V300DebtDirect, V300DebtEngine} from "./CMTATv300Variants.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";

/**
 * @title RuleMaxTotalSupply on CMTAT v3.0.0
 * @notice v3.0.0 notifies the engine BEFORE `_mint` / `_burn`, which is the accounting the rule assumes:
 * `totalSupply()` does not yet include the amount being minted.
 */
abstract contract RuleMaxTotalSupplyV300Test is CMTATv300TestBase {
    uint256 constant CAP = 100;
    RuleMaxTotalSupply internal rule;

    function setUp() public {
        _deployToken();
        rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        _attach(address(rule));
        _mint(ADDRESS1, 60);
    }

    function testMintLandingExactlyOnTheCap() public {
        _assertCode(ZERO_ADDRESS, ADDRESS2, 40, TRANSFER_OK);
        _mint(ADDRESS2, 40);
        assertEq(token.totalSupply(), CAP);
    }

    function testRemainingMintableTracksMintsAndBurns() public {
        (uint8 code, uint256 headroom) = rule.remainingMintable();
        assertEq(code, TRANSFER_OK);
        assertEq(headroom, 40);
        _mint(ADDRESS2, 40);
        (, headroom) = rule.remainingMintable();
        assertEq(headroom, 0);
        _burn(ADDRESS1, 15);
        (, headroom) = rule.remainingMintable();
        assertEq(headroom, 15);
    }

    function testCannotMintAboveTheCap() public {
        _assertCode(ZERO_ADDRESS, ADDRESS2, 41, CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 41);
    }

    function testTransfersAreNotCapped() public {
        _mint(ADDRESS2, 40);
        _transfer(ADDRESS1, ADDRESS2, 60);
        assertEq(token.balanceOf(ADDRESS2), 100);
    }

    function testBurnFreesHeadroom() public {
        _mint(ADDRESS2, 40);
        _burn(ADDRESS1, 10);
        _mint(ADDRESS2, 10);
        assertEq(token.totalSupply(), CAP);
    }

    /// @notice The burn leg runs first, so `burnAndMint` only needs room for the net increase.
    function testBurnAndMintNeedsRoomForTheNetIncreaseOnly() public {
        _mint(ADDRESS2, 40);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burnAndMint(ADDRESS1, ADDRESS3, 20, 20, "");
        assertEq(token.totalSupply(), CAP);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        token.burnAndMint(ADDRESS1, ADDRESS3, 10, 11, "");
    }

    /// @notice A forced burn bypasses the engine, but lowers `totalSupply()`, so the room shows at the next mint.
    function testForcedBurnFreesHeadroom() public {
        _mint(ADDRESS2, 40);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.forcedTransfer(ADDRESS1, ZERO_ADDRESS, 30);
        _mint(ADDRESS2, 30);
        assertEq(token.totalSupply(), CAP);
    }

    function testSettingTheCapBelowSupplyFreezesMintsOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(0);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 1);
        _transfer(ADDRESS1, ADDRESS2, 10);
        _burn(ADDRESS1, 10);
        assertEq(token.totalSupply(), 50);
    }

    /// @notice Detaching lifts the cap; supply minted meanwhile is counted on re-attach, because the
    /// rule reads the live `totalSupply()` and keeps no counter of its own.
    function testSupplyMintedWhileDetachedIsCountedOnReattach() public {
        _detach();
        _mint(ADDRESS2, 70); // 130 > CAP: nothing checks it while detached
        _reattach(_viaEngine() ? address(engine) : address(rule));
        (, uint256 headroom) = rule.remainingMintable();
        assertEq(headroom, 0);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        _mint(ADDRESS2, 1);
        _burn(ADDRESS2, 40); // back to 90
        _mint(ADDRESS2, 10);
        assertEq(token.totalSupply(), CAP);
    }

    /// @notice Standard only: cross-chain mints are capped and cross-chain burns free room.
    function testCrosschainMintAndBurn() public {
        if (_isDebt()) return;
        // `crosschainBurn` spends the holder's allowance to the bridge (here the admin, holding CROSS_CHAIN_ROLE).
        _approve(ADDRESS1, DEFAULT_ADMIN_ADDRESS, 10);
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectPartialRevert(RuleMaxTotalSupply_InvalidTransfer.selector);
        token.crosschainMint(ADDRESS2, 41);
        token.crosschainBurn(ADDRESS1, 10);
        token.crosschainMint(ADDRESS2, 50);
        vm.stopPrank();
        assertEq(token.totalSupply(), CAP);
    }
}

contract RuleMaxTotalSupplyV300StandardDirectTest is RuleMaxTotalSupplyV300Test, V300StandardDirect {}

contract RuleMaxTotalSupplyV300StandardEngineTest is RuleMaxTotalSupplyV300Test, V300StandardEngine {}

contract RuleMaxTotalSupplyV300DebtDirectTest is RuleMaxTotalSupplyV300Test, V300DebtDirect {}

contract RuleMaxTotalSupplyV300DebtEngineTest is RuleMaxTotalSupplyV300Test, V300DebtEngine {}
