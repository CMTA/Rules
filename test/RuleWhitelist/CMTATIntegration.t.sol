// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";

/**
 * @title Integration test with the CMTAT
 */
contract CMTATIntegration is Test, HelperContract {
    uint256 constant ADDRESS1_BALANCE_INIT = 31;
    uint256 constant ADDRESS2_BALANCE_INIT = 32;
    uint256 constant ADDRESS3_BALANCE_INIT = 33;

    // Arrange
    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false);
        // global arrange
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        // specific arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleWhitelist);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, ADDRESS1_BALANCE_INIT);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS2, ADDRESS2_BALANCE_INIT);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS3, ADDRESS3_BALANCE_INIT);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        // We set the Rule Engine
        cmtatContract.setRuleEngine(ruleEngineMock);
    }

    /**
     * Transfer ******
     */
    function testCannotTransferWithoutAddressWhitelisted() public {
        // Arrange
        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                21,
                CODE_ADDRESS_FROM_NOT_WHITELISTED
            )
        );
        // Act
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, 21);
    }

    function testCannotTransferWithoutFromAddressWhitelisted() public {
        // Arrange
        uint256 amount = 21;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_FROM_NOT_WHITELISTED
            )
        );
        // Act
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, amount);
    }

    function testCannotTransferWithoutToAddressWhitelisted() public {
        // Arrange
        uint256 amount = 21;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_TO_NOT_WHITELISTED
            )
        );
        // Act
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, amount);
    }

    function testCanMakeATransfer() public {
        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        require(success);
        vm.prank(ADDRESS1);

        // Act
        assertTrue(cmtatContract.transfer(ADDRESS2, 11));

        // Assert
        resUint256 = cmtatContract.balanceOf(ADDRESS1);
        assertEq(resUint256, 20);
        resUint256 = cmtatContract.balanceOf(ADDRESS2);
        assertEq(resUint256, 43);
        resUint256 = cmtatContract.balanceOf(ADDRESS3);
        assertEq(resUint256, 33);
    }

    /**
     * detectTransferRestriction & messageForTransferRestriction ******
     */
    function testDetectAndMessageWithFromNotWhitelisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        // Assert
        assertEq(resBool, true);
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithToNotWhitelisted() public {
        // Arrange
        // We add the sender to the whitelist
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        // Act
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        // Assert
        assertEq(res1, CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_ADDRESS_TO_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithFromAndToNotWhitelisted() public view {
        // Act
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);

        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);

        // Assert
        assertEq(message1, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
    }

    function testDetectAndMessageWithAValidTransfer() public {
        // Arrange
        // We add the sender and the recipient to the whitelist.
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        require(success);
        // Act
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        // Assert
        assertEq(res1, TRANSFER_OK);
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_TRANSFER_OK);
    }

    function testCanMint() public {
        // Arrange
        // Permit minting via the explicit flag (the zero address is never whitelisted)
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.setAllowMint(true);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // Arrange - Assert: the sentinel is NOT listed; the explicit flag is what permits the mint.
        assertFalse(ruleWhitelist.isAddressListed(ZERO_ADDRESS));
        assertTrue(ruleWhitelist.allowMint());

        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 11);

        // Assert
        resUint256 = cmtatContract.balanceOf(ADDRESS1);
        assertEq(resUint256, ADDRESS1_BALANCE_INIT + 11);
    }
}
