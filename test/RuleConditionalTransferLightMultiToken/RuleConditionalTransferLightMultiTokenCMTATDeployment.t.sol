// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {
    RuleConditionalTransferLightMultiTokenInvariantStorage as MultiTokenStorage
} from "src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenInvariantStorage.sol";

/**
 * @title RuleConditionalTransferLightMultiToken set at deployment of the current CMTAT (>= v3.3)
 * @notice One rule passed in the constructor of two tokens (direct binding, the only supported topology). Each
 * token is blocked until bound, and an approval recorded for one token never authorises a transfer of the other.
 */
contract RuleConditionalTransferLightMultiTokenCMTATDeployment is Test, HelperContract {
    RuleConditionalTransferLightMultiToken private rule;
    CMTATStandardStandalone private tokenA;
    CMTATStandardStandalone private tokenB;

    function setUp() public {
        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        tokenA = _deployToken(address(rule));
        tokenB = _deployToken(address(rule));
    }

    function _deployToken(address ruleEngine_) private returns (CMTATStandardStandalone) {
        return new CMTATStandardStandalone(
            ZERO_ADDRESS,
            DEFAULT_ADMIN_ADDRESS,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("Terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(ruleEngine_))
        );
    }

    /// @notice Each token is blocked until bound; approvals stay scoped to the token they name.
    function testRuleInConstructorOfTwoTokens() public {
        assertEq(address(tokenA.ruleEngine()), address(rule));

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiTokenStorage.RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized.selector,
                address(tokenA)
            )
        );
        tokenA.mint(ADDRESS1, 100);

        rule.bindToken(address(tokenA));
        rule.bindToken(address(tokenB));
        tokenA.mint(ADDRESS1, 100);
        tokenB.mint(ADDRESS1, 100);
        rule.approveTransfer(address(tokenA), ADDRESS1, ADDRESS2, 10);
        vm.stopPrank();

        // Token-side views ask with the token as caller; a third party must name the token explicitly.
        assertEq(tokenA.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        assertEq(tokenB.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_TRANSFER_REQUEST_NOT_APPROVED);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_TRANSFER_REQUEST_NOT_APPROVED);
        assertEq(rule.detectTransferRestrictionForToken(address(tokenA), ADDRESS1, ADDRESS2, 10), TRANSFER_OK);

        vm.prank(ADDRESS1);
        vm.expectRevert(MultiTokenStorage.RuleConditionalTransferLightMultiToken_TransferNotApproved.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        tokenB.transfer(ADDRESS2, 10);

        vm.prank(ADDRESS1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        tokenA.transfer(ADDRESS2, 10);
        assertEq(rule.approvedCount(address(tokenA), ADDRESS1, ADDRESS2, 10), 0);

        vm.prank(ADDRESS1);
        tokenB.approve(address(rule), 5);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveAndTransferIfAllowed(address(tokenB), ADDRESS1, ADDRESS2, 5);
        assertEq(tokenB.balanceOf(ADDRESS2), 5);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        tokenA.burn(ADDRESS2, 10);
        assertEq(tokenA.totalSupply(), 90);
    }
}
