// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleChainlinkPoRERC3643} from "src/rules/validation/deployment/RuleChainlinkPoRERC3643.sol";
import {
    RuleChainlinkPoRERC3643Ownable2Step
} from "src/rules/validation/deployment/RuleChainlinkPoRERC3643Ownable2Step.sol";

/**
 * @title RuleChainlinkPoRERC3643Unit
 * @notice Unit coverage for the ERC-3643 Proof-of-Reserve variants, in the default profile.
 * @dev The end-to-end proof runs against the genuine vendored token in
 *      `test/ERC3643Real/ERC3643RealTokenChainlinkPoR.t.sol` under `FOUNDRY_PROFILE=erc3643`, which
 *      `forge test` and `forge coverage` do not include. These tests exercise the same override with
 *      mocks so the variants are covered by the ordinary run too.
 *
 *      The rule is notified as an ERC-3643 token would notify it: the supply is set to its POST-mint
 *      value first, then the write hook is called.
 */
contract RuleChainlinkPoRERC3643Unit is Test, HelperContract {
    uint256 private constant RESERVES = 1000;

    TotalSupplyMock private token;
    AggregatorV3Mock private feed;

    function setUp() public {
        token = new TotalSupplyMock();
        feed = new AggregatorV3Mock(0, int256(RESERVES));
    }

    function _accessControlVariant() private returns (RuleChainlinkPoRERC3643) {
        return
            new RuleChainlinkPoRERC3643(
                DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), 0
            );
    }

    function _ownableVariant() private returns (RuleChainlinkPoRERC3643Ownable2Step) {
        return new RuleChainlinkPoRERC3643Ownable2Step(
            DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ENFORCEMENT (POST-MINT)
    //////////////////////////////////////////////////////////////*/

    function testNotifyAcceptsAMintThatLandsExactlyOnTheReserves() public {
        RuleChainlinkPoRERC3643 rule = _accessControlVariant();
        token.setTotalSupply(RESERVES); // the mint has already happened
        rule.transferred(ZERO_ADDRESS, ADDRESS1, RESERVES);
    }

    function testNotifyRejectsAMintThatLandsAboveTheReserves() public {
        RuleChainlinkPoRERC3643 rule = _accessControlVariant();
        token.setTotalSupply(RESERVES + 1);
        vm.expectRevert();
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testNotifyAcceptsTransfersAndBurnsWhateverTheReserves() public {
        RuleChainlinkPoRERC3643 rule = _accessControlVariant();
        feed.setAnswer(0);
        token.setTotalSupply(RESERVES);

        rule.transferred(ADDRESS1, ADDRESS2, 10); // transfer
        rule.transferred(ADDRESS1, ZERO_ADDRESS, 10); // burn
        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10); // delegated transfer
    }

    function testDelegatedNotifyIsRePhasedToo() public {
        RuleChainlinkPoRERC3643 rule = _accessControlVariant();
        token.setTotalSupply(RESERVES);
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, RESERVES);

        token.setTotalSupply(RESERVES + 1);
        vm.expectRevert();
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    THE READ PATH IS NOT RE-PHASED
    //////////////////////////////////////////////////////////////*/

    function testReadPathStillProjectsThePendingAmount() public {
        RuleChainlinkPoRERC3643 rule = _accessControlVariant();
        token.setTotalSupply(RESERVES);

        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_RESERVES_EXCEEDED);
        assertFalse(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, 1));

        token.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, RESERVES), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, RESERVES + 1), CODE_RESERVES_EXCEEDED);
    }

    /// @notice Pre-flight and enforcement must agree on the same mint, as the ERC-3643 token calls both.
    function testPreFlightAndEnforcementAgree() public {
        RuleChainlinkPoRERC3643 rule = _accessControlVariant();

        // Pre-flight, before the mint: supply 0, asking for the full reserves.
        token.setTotalSupply(0);
        assertTrue(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, RESERVES));

        // Enforcement, after the mint: supply is now RESERVES.
        token.setTotalSupply(RESERVES);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, RESERVES);
    }

    /*//////////////////////////////////////////////////////////////
                    CONTRAST WITH THE STOCK RULE
    //////////////////////////////////////////////////////////////*/

    function testStockRuleDoubleCountsWhereTheVariantDoesNot() public {
        RuleChainlinkPoR stock =
            new RuleChainlinkPoR(DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), 0);
        RuleChainlinkPoRERC3643 variant = _accessControlVariant();

        token.setTotalSupply(RESERVES);

        vm.expectRevert();
        stock.transferred(ZERO_ADDRESS, ADDRESS1, RESERVES);

        variant.transferred(ZERO_ADDRESS, ADDRESS1, RESERVES);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNABLE2STEP VARIANT
    //////////////////////////////////////////////////////////////*/

    function testOwnableVariantEnforcesIdentically() public {
        RuleChainlinkPoRERC3643Ownable2Step rule = _ownableVariant();

        token.setTotalSupply(RESERVES);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, RESERVES);

        token.setTotalSupply(RESERVES + 1);
        vm.expectRevert();
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testOwnableVariantKeepsItsOwnerGatedConfiguration() public {
        RuleChainlinkPoRERC3643Ownable2Step rule = _ownableVariant();

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.setMaxStalenessSeconds(1 days);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxStalenessSeconds(1 days);
        assertEq(rule.maxStalenessSeconds(), 1 days);
    }

    function testBothVariantsReportTheSameBackedSupply() public {
        (uint8 codeA, uint256 backedA) = _accessControlVariant().maxBackedSupply();
        (uint8 codeB, uint256 backedB) = _ownableVariant().maxBackedSupply();
        assertEq(codeA, 0);
        assertEq(codeA, codeB);
        assertEq(backedA, RESERVES);
        assertEq(backedA, backedB);
    }
}
