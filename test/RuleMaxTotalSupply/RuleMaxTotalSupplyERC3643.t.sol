// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleMaxTotalSupplyERC3643} from "src/rules/validation/deployment/RuleMaxTotalSupplyERC3643.sol";
import {
    RuleMaxTotalSupplyERC3643Ownable2Step
} from "src/rules/validation/deployment/RuleMaxTotalSupplyERC3643Ownable2Step.sol";

/**
 * @title RuleMaxTotalSupplyERC3643Unit
 * @notice Unit coverage for the ERC-3643 supply-cap variants, in the default profile.
 * @dev The end-to-end proof runs against the genuine vendored token in
 *      `test/ERC3643Real/ERC3643RealTokenMaxTotalSupply.t.sol` under `FOUNDRY_PROFILE=erc3643`, which
 *      `forge test` and `forge coverage` do not include. These tests exercise the same override with
 *      a mock so the variants are covered by the ordinary run too.
 *
 *      The rule is notified as an ERC-3643 token would notify it: the supply is set to its POST-mint
 *      value first, then the write hook is called.
 */
contract RuleMaxTotalSupplyERC3643Unit is Test, HelperContract {
    uint256 private constant CAP = 1000;

    TotalSupplyMock private token;

    function setUp() public {
        token = new TotalSupplyMock();
    }

    function _accessControlVariant() private returns (RuleMaxTotalSupplyERC3643) {
        return new RuleMaxTotalSupplyERC3643(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
    }

    function _ownableVariant() private returns (RuleMaxTotalSupplyERC3643Ownable2Step) {
        return new RuleMaxTotalSupplyERC3643Ownable2Step(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
    }

    /*//////////////////////////////////////////////////////////////
                        ENFORCEMENT (POST-MINT)
    //////////////////////////////////////////////////////////////*/

    function testNotifyAcceptsAMintThatLandsExactlyOnTheCap() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();
        token.setTotalSupply(CAP); // the mint has already happened
        rule.transferred(ZERO_ADDRESS, ADDRESS1, CAP);
    }

    function testNotifyRejectsAMintThatLandsAboveTheCap() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();
        token.setTotalSupply(CAP + 1);
        vm.expectRevert();
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testNotifyAcceptsTransfersAndBurnsRegardlessOfSupply() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();
        token.setTotalSupply(CAP * 10); // already far over the cap

        rule.transferred(ADDRESS1, ADDRESS2, 10); // transfer
        rule.transferred(ADDRESS1, ZERO_ADDRESS, 10); // burn
        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10); // delegated transfer
    }

    function testDelegatedNotifyIsRePhasedToo() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();
        token.setTotalSupply(CAP);
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, CAP);

        token.setTotalSupply(CAP + 1);
        vm.expectRevert();
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testLoweringTheCapBelowTheSupplyBlocksFurtherMints() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();
        token.setTotalSupply(CAP);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(CAP / 2);

        vm.expectRevert();
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    /*//////////////////////////////////////////////////////////////
                    THE READ PATH IS NOT RE-PHASED
    //////////////////////////////////////////////////////////////*/

    function testReadPathStillProjectsThePendingAmount() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();
        token.setTotalSupply(CAP);

        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
        assertFalse(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, 1));

        token.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, CAP + 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
    }

    /// @notice Pre-flight and enforcement must agree on the same mint, as the ERC-3643 token calls both.
    function testPreFlightAndEnforcementAgree() public {
        RuleMaxTotalSupplyERC3643 rule = _accessControlVariant();

        token.setTotalSupply(0);
        assertTrue(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, CAP));

        token.setTotalSupply(CAP);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, CAP);
    }

    /*//////////////////////////////////////////////////////////////
                    CONTRAST WITH THE STOCK RULE
    //////////////////////////////////////////////////////////////*/

    function testStockRuleDoubleCountsWhereTheVariantDoesNot() public {
        RuleMaxTotalSupply stock = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), CAP);
        RuleMaxTotalSupplyERC3643 variant = _accessControlVariant();

        token.setTotalSupply(CAP);

        vm.expectRevert();
        stock.transferred(ZERO_ADDRESS, ADDRESS1, CAP);

        variant.transferred(ZERO_ADDRESS, ADDRESS1, CAP);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNABLE2STEP VARIANT
    //////////////////////////////////////////////////////////////*/

    function testOwnableVariantEnforcesIdentically() public {
        RuleMaxTotalSupplyERC3643Ownable2Step rule = _ownableVariant();

        token.setTotalSupply(CAP);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, CAP);

        token.setTotalSupply(CAP + 1);
        vm.expectRevert();
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testOwnableVariantKeepsItsOwnerGatedConfiguration() public {
        RuleMaxTotalSupplyERC3643Ownable2Step rule = _ownableVariant();

        vm.prank(ATTACKER);
        vm.expectRevert();
        rule.setMaxTotalSupply(1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxTotalSupply(1);
        assertEq(rule.maxTotalSupply(), 1);
    }
}
