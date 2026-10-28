// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";

/**
 * @title End-to-end integration test: CMTAT + RuleEngine + RuleChainlinkPoR
 * @notice Verifies that the Proof of Reserve backing is enforced through the full CMTAT call chain,
 *         and that transfers and burns stay unaffected.
 */
contract RuleChainlinkPoRCMTATIntegration is Test, HelperContract {
    address constant MINTER = address(10);
    uint8 constant FEED_DECIMALS = 8;
    uint256 constant ONE_DAY = 1 days;

    AggregatorV3Mock private feed;
    RuleChainlinkPoR private rule;
    uint8 private cmtatDecimals;

    function setUp() public {
        vm.warp(1_000_000);
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();
        cmtatDecimals = cmtatContract.decimals();

        // 1_000 reserve units, reported with 8 decimals.
        feed = new AggregatorV3Mock(FEED_DECIMALS, 1000 * 1e8);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(cmtatContract), cmtatDecimals, AggregatorV3Interface(address(feed)), ONE_DAY
        );

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(rule);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("MINTER_ROLE"), MINTER);
    }

    /**
     * @notice Reserve expressed in the token's own units.
     */
    function _reserveInTokenUnits() private view returns (uint256) {
        return 1000 * (10 ** uint256(cmtatDecimals));
    }

    function testMintSucceedsWhenBackedByReserves() public {
        uint256 amount = _reserveInTokenUnits();

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, amount);

        assertEq(cmtatContract.balanceOf(ADDRESS1), amount);
    }

    function testMintRevertsWhenExceedingReserves() public {
        uint256 amount = _reserveInTokenUnits() + 1;

        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, amount);

        assertEq(cmtatContract.balanceOf(ADDRESS1), 0);
    }

    function testSecondMintIsCheckedAgainstTheUpdatedSupply() public {
        uint256 half = _reserveInTokenUnits() / 2;

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, half);

        // The remaining headroom is exactly `half`.
        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, half);

        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, 1);
    }

    function testMintUnlockedByAReserveIncrease() public {
        uint256 amount = _reserveInTokenUnits();

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, amount);

        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, amount);

        // Reserves double: the previously rejected mint now goes through.
        feed.setAnswer(2000 * 1e8);

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, amount);

        assertEq(cmtatContract.balanceOf(ADDRESS1), 2 * amount);
    }

    function testStaleFeedBlocksMintButNotTransfersOrBurns() public {
        uint256 amount = _reserveInTokenUnits();

        vm.prank(MINTER);
        cmtatContract.mint(ADDRESS1, amount);

        vm.warp(block.timestamp + ONE_DAY + 1);
        assertEq(ruleEngineMock.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_RESERVES_FEED_STALE);

        vm.prank(MINTER);
        vm.expectRevert();
        cmtatContract.mint(ADDRESS1, 1);

        // Holders can still move and burn their tokens while the feed is stale.
        vm.prank(ADDRESS1);
        assertTrue(cmtatContract.transfer(ADDRESS2, amount / 2));

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.grantRole(keccak256("BURNER_ROLE"), DEFAULT_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.burn(ADDRESS1, amount / 2, "burn while stale");
    }

    function testRuleEngineViewsReflectTheReserveLimit() public {
        uint256 amount = _reserveInTokenUnits();

        assertEq(ruleEngineMock.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, amount), TRANSFER_OK);
        assertTrue(ruleEngineMock.canTransfer(ZERO_ADDRESS, ADDRESS1, amount));

        assertEq(ruleEngineMock.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, amount + 1), CODE_RESERVES_EXCEEDED);
        assertFalse(ruleEngineMock.canTransfer(ZERO_ADDRESS, ADDRESS1, amount + 1));
    }

    function testMessageIsResolvedThroughTheRuleEngine() public view {
        assertEq(ruleEngineMock.messageForTransferRestriction(CODE_RESERVES_EXCEEDED), TEXT_RESERVES_EXCEEDED);
        assertEq(ruleEngineMock.messageForTransferRestriction(CODE_RESERVES_FEED_STALE), TEXT_RESERVES_FEED_STALE);
        assertEq(
            ruleEngineMock.messageForTransferRestriction(CODE_RESERVES_ANSWER_INVALID), TEXT_RESERVES_ANSWER_INVALID
        );
    }
}
