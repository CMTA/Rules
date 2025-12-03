// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "CMTAT/deployment/CMTATStandalone.sol";
import "../HelperContract.sol";


/**
 * @title Integration test with the CMTAT using direct RuleBlacklist
 */
contract CMTATIntegrationDirectBlacklist is Test, HelperContract {
    uint256 ADDRESS1_BALANCE_INIT = 31;
    uint256 ADDRESS2_BALANCE_INIT = 32;
    uint256 ADDRESS3_BALANCE_INIT = 33;

    function setUp() public {
        // Deploy CMTAT
        cmtatDeployment = new CMTATDeployment();
        CMTAT_CONTRACT = cmtatDeployment.cmtat();

        // Deploy RuleBlacklist directly
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);

        // Mint initial balances
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTAT_CONTRACT.mint(ADDRESS1, ADDRESS1_BALANCE_INIT);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTAT_CONTRACT.mint(ADDRESS2, ADDRESS2_BALANCE_INIT);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTAT_CONTRACT.mint(ADDRESS3, ADDRESS3_BALANCE_INIT);

        // Directly plug the blacklist into CMTAT
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTAT_CONTRACT.setRuleEngine(IRuleEngine(address(ruleBlacklist)));
    }

    /* ---------------- Transfer Tests ---------------- */

    function testCanTransferIfAddressNotBlacklisted() public {
        vm.prank(ADDRESS1);
        CMTAT_CONTRACT.transfer(ADDRESS2, 21);
    }

    function testCannotTransferIfAddressToIsBlacklisted() public {
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
        CMTAT_CONTRACT.transfer(ADDRESS2, amount);
    }

    function testCannotTransferIfAddressFromIsBlacklisted() public {
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
        CMTAT_CONTRACT.transfer(ADDRESS2, amount);
    }

    function testCannotTransferIfBothAddressesAreBlacklisted() public {
        uint256 amount = 21;
        address[] memory blacklist = new address[](2);
        blacklist[0] = ADDRESS1;
        blacklist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success,) = address(ruleBlacklist).call(abi.encodeWithSignature("addAddresses(address[])", blacklist));
        require(success);

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
        CMTAT_CONTRACT.transfer(ADDRESS2, amount);
    }

    /* ---------------- Detect & Message Tests ---------------- */

    function testDetectAndMessageWithToBlacklisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS2);
        bool resBool = ruleBlacklist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);

        uint8 res1 = CMTAT_CONTRACT.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        assertEq(res1, CODE_ADDRESS_TO_IS_BLACKLISTED);

        string memory message1 = CMTAT_CONTRACT.messageForTransferRestriction(res1);
        assertEq(message1, TEXT_ADDRESS_TO_IS_BLACKLISTED);
    }

    function testDetectAndMessageWithFromBlacklisted() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);
        bool resBool = ruleBlacklist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);

        uint8 res1 = CMTAT_CONTRACT.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        assertEq(res1, CODE_ADDRESS_FROM_IS_BLACKLISTED);

        string memory message1 = CMTAT_CONTRACT.messageForTransferRestriction(res1);
        assertEq(message1, TEXT_ADDRESS_FROM_IS_BLACKLISTED);
    }

    function testDetectAndMessageWithFromAndToNotBlacklisted() public view {
        uint8 res1 = CMTAT_CONTRACT.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        assertEq(res1, TRANSFER_OK);

        string memory message1 = CMTAT_CONTRACT.messageForTransferRestriction(res1);
        assertEq(message1, TEXT_TRANSFER_OK);
    }

    function testDetectAndMessageWithFromAndToBlacklisted() public {
        address[] memory blacklist = new address[](2);
        blacklist[0] = ADDRESS1;
        blacklist[1] = ADDRESS2;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool success,) = address(ruleBlacklist).call(abi.encodeWithSignature("addAddresses(address[])", blacklist));
        require(success);

        uint8 res1 = CMTAT_CONTRACT.detectTransferRestriction(ADDRESS1, ADDRESS2, 11);
        assertEq(res1, CODE_ADDRESS_FROM_IS_BLACKLISTED);

        string memory message1 = CMTAT_CONTRACT.messageForTransferRestriction(res1);
        assertEq(message1, TEXT_ADDRESS_FROM_IS_BLACKLISTED);
    }

    /* ---------------- Mint Tests ---------------- */

    function testCanMintIfAddressNotInTheBlacklist() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTAT_CONTRACT.mint(ADDRESS1, 11);

        uint256 resUint256 = CMTAT_CONTRACT.balanceOf(ADDRESS1);
        assertEq(resUint256, ADDRESS1_BALANCE_INIT + 11);
    }

    function testCannotMintIfAddressIsInTheBlacklist() public {
        uint256 amount = 11;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleBlacklist.addAddress(ADDRESS1);
        bool resBool = ruleBlacklist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleBlacklist_InvalidTransfer.selector,
                address(ruleBlacklist),
                ZERO_ADDRESS,
                ADDRESS1,
                amount,
                CODE_ADDRESS_TO_IS_BLACKLISTED
            )
        );
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        CMTAT_CONTRACT.mint(ADDRESS1, amount);
    }

    function testCanReturnMessageNotFoundWithUnknownCodeId() public view {
        string memory message1 = CMTAT_CONTRACT.messageForTransferRestriction(255);
        assertEq(message1, TEXT_CODE_NOT_FOUND);
    }
}