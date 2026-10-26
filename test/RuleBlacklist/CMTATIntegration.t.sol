// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";

/**
 * @title Integration test with the CMTAT
 */
contract CMTATIntegration is Test, HelperContract {
    uint256 constant ADDRESS1_BALANCE_INIT = 31;
    uint256 constant ADDRESS2_BALANCE_INIT = 32;
    uint256 constant ADDRESS3_BALANCE_INIT = 33;

    // Arrange
    function setUp() public {
        // CMTAT
        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        // specific arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleBlacklist);
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
    function testCanTransferIfAddressNotBlacklisted() public {
        // Act
        vm.prank(ADDRESS1);
        assertTrue(cmtatContract.transfer(ADDRESS2, 21));
    }

    function testCannotTransferIfAddressToIsBlacklisted() public {
        // Arrange
        uint256 amount = 21;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS2);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransfer.selector,
                address(ruleBlacklist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_TO_IS_BLACKLISTED
            )
        );
        // Act
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, amount);
    }

    function testCannotTransferIfAddressFronIsBlacklisted() public {
        // Arrange
        uint256 amount = 21;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransfer.selector,
                address(ruleBlacklist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_FROM_IS_BLACKLISTED
            )
        );
        // Act
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, amount);
    }

    function testCannotTransferIfBothAddressesAreBlacklisted() public {
        uint256 amount = 21;
        // Arrange
        address[] memory blacklist = new address[](2);
        blacklist[0] = ADDRESS1;
        blacklist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success,) = address(ruleBlacklist).call(abi.encodeWithSignature("addAddresses(address[])", blacklist));
        require(success);

        // Act
        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransfer.selector,
                address(ruleBlacklist),
                ADDRESS1,
                ADDRESS2,
                amount,
                CODE_ADDRESS_FROM_IS_BLACKLISTED
            )
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        cmtatContract.transfer(ADDRESS2, amount);
    }

    /**
     * detectTransferRestriction & messageForTransferRestriction ******
     */
    function testDetectAndMessageWithToBlacklisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS2);
        resBool = ruleBlacklist.isAddressListed(ADDRESS2);
        // Assert
        assertEq(resBool, true);
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        // Assert
        assertEq(res1, CODE_ADDRESS_TO_IS_BLACKLISTED);
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_ADDRESS_TO_IS_BLACKLISTED);
    }

    function testDetectAndMessageWithFromBlacklisted() public {
        // Arrange
        // We add the sender to the whitelist
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);
        // Arrange - Assert
        resBool = ruleBlacklist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        // Act
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_IS_BLACKLISTED);
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_ADDRESS_FROM_IS_BLACKLISTED);
    }

    function testDetectAndMessageWithFromAndToNotBlacklisted() public view {
        // Act
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);

        // Assert
        assertEq(res1, TRANSFER_OK);
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_TRANSFER_OK);
    }

    function testDetectAndMessageWithFromAndToBlacklisted() public {
        // Arrange
        // We add the sender and the recipient to the whitelist.
        address[] memory blacklist = new address[](2);
        blacklist[0] = ADDRESS1;
        blacklist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success,) = address(ruleBlacklist).call(abi.encodeWithSignature("addAddresses(address[])", blacklist));
        require(success);
        // Act
        uint8 res1 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        // Assert
        assertEq(res1, CODE_ADDRESS_FROM_IS_BLACKLISTED);
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(res1);
        // Assert
        assertEq(message1, TEXT_ADDRESS_FROM_IS_BLACKLISTED);
    }

    function testCanMintIfAddressNotInTheBlacklist() public {
        // Act
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, 11);

        // Assert
        resUint256 = cmtatContract.balanceOf(ADDRESS1);
        assertEq(resUint256, ADDRESS1_BALANCE_INIT + 11);
    }

    function testCannotMintIfAddressIsInTheBlacklist() public {
        uint256 amount = 11;
        // Arrange
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);
        // Arrange - Assert
        resBool = ruleBlacklist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransferFrom.selector,
                address(ruleBlacklist),
                DEFAULT_ADMIN_ADDRESS,
                ZERO_ADDRESS,
                ADDRESS1,
                amount,
                CODE_ADDRESS_TO_IS_BLACKLISTED
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, amount);
    }

    function testCanReturnMessageNotFoundWithUnknownCodeId() public view {
        // Act
        string memory message1 = cmtatContract.messageForTransferRestriction(255);

        // Assert
        assertEq(message1, TEXT_CODE_NOT_FOUND);
    }
}
