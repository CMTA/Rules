// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {DeployCMTATWithSanctionsList} from "script/DeployCMTATWithSanctionsList.s.sol";

contract DeployCMTATWithSanctionsListTest is Test {
    address constant ADMIN = address(1);
    address constant INVESTOR = address(2);
    address constant SANCTIONED = address(3);

    /// RuleSanctionsListInvariantStorage.CODE_ADDRESS_FROM_IS_SANCTIONED / CODE_ADDRESS_TO_IS_SANCTIONED
    uint8 constant CODE_ADDRESS_FROM_IS_SANCTIONED = 30;
    uint8 constant CODE_ADDRESS_TO_IS_SANCTIONED = 31;

    DeployCMTATWithSanctionsList script;
    SanctionListOracle oracle;
    CMTATStandardStandalone token;
    RuleSanctionsList rule;

    function setUp() public {
        script = new DeployCMTATWithSanctionsList();
        oracle = new SanctionListOracle();
        oracle.addToSanctionsList(SANCTIONED);
        // The script contract is the acting deployer: a direct deploy() call is not a broadcast.
        (token, rule) = script.deploy(ADMIN, address(script), address(0), ISanctionsList(address(oracle)));
    }

    function testSetsTheRuleOnTheTokenWithTheOracle() public view {
        assertEq(address(token.ruleEngine()), address(rule));
        assertEq(address(rule.sanctionsList()), address(oracle));
    }

    function testHandsAdminRoleToAdmin() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    function testDeployerRetainsNoAdminRole() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
        assertFalse(rule.hasRole(rule.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testAdminEqualToDeployerKeepsTheRole() public {
        (CMTATStandardStandalone t2, RuleSanctionsList r2) =
            script.deploy(address(script), address(script), address(0), ISanctionsList(address(oracle)));
        assertTrue(t2.hasRole(t2.DEFAULT_ADMIN_ROLE(), address(script)));
        assertTrue(r2.hasRole(r2.DEFAULT_ADMIN_ROLE(), address(script)));
    }

    function testMintToACleanInvestorSucceeds() public {
        assertEq(token.detectTransferRestriction(address(0), INVESTOR, 100), 0);
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testTransferToASanctionedAddressIsRejected() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);

        assertEq(token.detectTransferRestriction(INVESTOR, SANCTIONED, 1), CODE_ADDRESS_TO_IS_SANCTIONED);
        vm.prank(INVESTOR);
        vm.expectRevert();
        token.transfer(SANCTIONED, 1);
    }

    function testMintToASanctionedAddressIsRejected() public {
        assertEq(token.detectTransferRestriction(address(0), SANCTIONED, 100), CODE_ADDRESS_TO_IS_SANCTIONED);
        vm.prank(ADMIN);
        vm.expectRevert();
        token.mint(SANCTIONED, 100);
    }

    /// A holder sanctioned after issuance can no longer send.
    function testTransferFromASanctionedHolderIsRejected() public {
        vm.prank(ADMIN);
        token.mint(INVESTOR, 100);
        oracle.addToSanctionsList(INVESTOR);

        assertEq(token.detectTransferRestriction(INVESTOR, ADMIN, 1), CODE_ADDRESS_FROM_IS_SANCTIONED);
        vm.prank(INVESTOR);
        vm.expectRevert();
        token.transfer(ADMIN, 1);
    }

    /// The default `run()` oracle is address(0): screening is disabled and everything passes.
    function testUnsetOracleFailsOpen() public {
        (CMTATStandardStandalone t2, RuleSanctionsList r2) =
            script.deploy(ADMIN, address(script), address(0), ISanctionsList(address(0)));
        assertEq(address(r2.sanctionsList()), address(0));

        assertEq(t2.detectTransferRestriction(address(0), SANCTIONED, 100), 0);
        vm.prank(ADMIN);
        t2.mint(SANCTIONED, 100);
        assertEq(t2.balanceOf(SANCTIONED), 100);
    }
}
