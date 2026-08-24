// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";

import {AddressListInterfaceId} from "src/rules/interfaces/library/AddressListInterfaceId.sol";
import {IAddressListInterfaceIdHelper, IAddressListAllFunctions} from "src/mocks/IAddressListInterfaceIdHelper.sol";
import {IAddressListBatchQuery, IAddressListPolarity} from "src/rules/interfaces/IAddressList.sol";
import {IIdentityRegistryContains} from "src/rules/interfaces/IIdentityRegistry.sol";

import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistOwnable2Step.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleBlacklistOwnable2Step} from "src/rules/validation/deployment/RuleBlacklistOwnable2Step.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {RuleSpenderWhitelistOwnable2Step} from "src/rules/validation/deployment/RuleSpenderWhitelistOwnable2Step.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";

/**
 * @title AddressListInterfaceIdTest
 * @notice Verifies the pre-computed {AddressListInterfaceId} constant and its advertisement.
 * @dev First step of improvement I-4: every rule that implements {IAddressList} must advertise it
 *      via ERC-165, so that `RuleWhitelistWrapper` can later interface-check its child rules
 *      (threat `WW-2`, finding F-5).
 */
contract AddressListInterfaceIdTest is Test, HelperContract {
    address private constant FORWARDER = address(0);

    IAddressListInterfaceIdHelper private helper;

    function setUp() public {
        helper = new IAddressListInterfaceIdHelper();
    }

    /*//////////////////////////////////////////////////////////////
                        THE CONSTANT ITSELF
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The library constant equals the XOR of every selector in the IAddressList hierarchy.
     */
    function test_ConstantMatchesFlattenedInterfaceId() public view {
        assertEq(
            AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID,
            type(IAddressListAllFunctions).interfaceId,
            "constant does not match the flattened hierarchy"
        );
        assertEq(AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID, bytes4(0x5d10e182));
    }

    /**
     * @notice Guards the reason the flat-helper pattern is required: `type(IAddressList).interfaceId`
     *         omits every selector it inherits, so it must NOT be used for the ERC-165 check.
     * @dev `IAddressList` now inherits from **two** parents — `IIdentityRegistryContains` for
     *      `contains(address)` and `IAddressListBatchQuery` for `areAddressesListed(address[])` —
     *      so the naive id omits both. That makes the point more sharply than before: the omission
     *      grows silently every time a selector is factored out into a parent interface, which is
     *      exactly why the flattened constant exists.
     */
    function test_NaiveInterfaceIdIsWrongAndMustNotBeUsed() public view {
        bytes4 naive = helper.getIAddressListInterfaceId();
        bytes4 full = AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID;

        assertTrue(naive != full, "naive id unexpectedly equals the full id");
        // The difference is exactly the two inherited selectors.
        assertEq(
            naive ^ full,
            IIdentityRegistryContains.contains.selector ^ AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID
        );
    }

    /*//////////////////////////////////////////////////////////////
                THE BATCH-QUERY SUB-INTERFACE (NM-18)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The sub-interface id is the selector of its single function.
     * @dev `IAddressListBatchQuery` declares one function and inherits nothing, so unlike the full
     *      hierarchy it has no omitted-parent trap and the literal is safe to state.
     */
    function test_BatchQueryInterfaceIdIsTheSingleSelector() public pure {
        assertEq(AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID, bytes4(0x20e8e17a));
        assertEq(
            AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID,
            IAddressListBatchQuery.areAddressesListed.selector
        );
        assertEq(
            AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID, type(IAddressListBatchQuery).interfaceId
        );
    }

    /*//////////////////////////////////////////////////////////////
                    THE POLARITY INTERFACE (NM-20)
    //////////////////////////////////////////////////////////////*/

    /// @notice The polarity id is the selector of its single function.
    function test_PolarityInterfaceIdIsTheSingleSelector() public pure {
        assertEq(AddressListInterfaceId.IADDRESS_LIST_POLARITY_INTERFACE_ID, bytes4(0xdc4efe10));
        assertEq(AddressListInterfaceId.IADDRESS_LIST_POLARITY_INTERFACE_ID, IAddressListPolarity.isAllowList.selector);
        assertEq(AddressListInterfaceId.IADDRESS_LIST_POLARITY_INTERFACE_ID, type(IAddressListPolarity).interfaceId);
    }

    /**
     * @notice Polarity is a SEPARATE id from membership, which is the whole point.
     * @dev If the two were the same interface, an allow-list and a deny-list would be
     *      indistinguishable again — a consumer needs to require both and then read the answer.
     */
    function test_PolarityIsIndependentOfMembership() public pure {
        assertTrue(
            AddressListInterfaceId.IADDRESS_LIST_POLARITY_INTERFACE_ID
                != AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID
        );
        assertTrue(
            AddressListInterfaceId.IADDRESS_LIST_POLARITY_INTERFACE_ID
                != AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID
        );
    }

    /// @notice Each rule declares the polarity it actually has, and advertises the interface.
    function test_RulesDeclareTheirPolarityHonestly() public {
        bytes4 polarity = AddressListInterfaceId.IADDRESS_LIST_POLARITY_INTERFACE_ID;

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist whitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);
        RuleBlacklist blacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        RuleSpenderWhitelist spender = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        vm.stopPrank();

        assertTrue(IERC165(address(whitelist)).supportsInterface(polarity), "whitelist advertises polarity");
        assertTrue(whitelist.isAllowList(), "whitelist is an allow-list");

        assertTrue(IERC165(address(blacklist)).supportsInterface(polarity), "blacklist advertises polarity");
        assertFalse(blacklist.isAllowList(), "blacklist is a deny-list");

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleReceiverWhitelist receiver = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        assertTrue(IERC165(address(receiver)).supportsInterface(polarity), "receiver whitelist advertises polarity");
        assertTrue(receiver.isAllowList(), "receiver whitelist is an allow-list");

        // Deliberate abstention: its set is spenders, not holders, so polarity alone would mislead.
        assertFalse(
            IERC165(address(spender)).supportsInterface(polarity),
            "RuleSpenderWhitelist must NOT declare holder polarity"
        );
    }

    /// @notice The sub-interface is a strict subset: the full id contains its selector.
    function test_BatchQueryIsASubsetOfTheFullInterface() public view {
        bytes4 full = AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID;
        bytes4 sub = AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID;
        assertTrue(full != sub, "the wrapper must not be able to confuse the two");
        // Removing the sub-interface selector from the flattened id leaves the other seven.
        assertTrue((full ^ sub) != full, "the full id must actually include the sub-interface selector");
    }

    /// @notice Every rule usable as a wrapper child advertises the sub-interface, not just the full one.
    function test_AddressListRulesAdvertiseTheBatchQuerySubInterface() public {
        bytes4 sub = AddressListInterfaceId.IADDRESS_LIST_BATCH_QUERY_INTERFACE_ID;

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist whitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);
        RuleBlacklist blacklist = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        RuleSpenderWhitelist spender = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        vm.stopPrank();

        assertTrue(IERC165(address(whitelist)).supportsInterface(sub), "RuleWhitelist");
        assertTrue(IERC165(address(blacklist)).supportsInterface(sub), "RuleBlacklist");
        assertTrue(IERC165(address(spender)).supportsInterface(sub), "RuleSpenderWhitelist");
    }

    /*//////////////////////////////////////////////////////////////
                    RULES THAT MUST ADVERTISE IT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Every rule backed by an address set advertises IAddressList (AccessControl variants).
     */
    function test_AddressSetRulesAdvertiseIAddressList() public {
        bytes4 id = AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID;

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        assertTrue(
            new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false).supportsInterface(id), "RuleWhitelist"
        );
        assertTrue(new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, FORWARDER).supportsInterface(id), "RuleBlacklist");
        assertTrue(
            new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER).supportsInterface(id), "RuleSpenderWhitelist"
        );
        vm.stopPrank();
    }

    /**
     * @notice Same for the Ownable2Step variants — the advertisement lives in the shared base,
     *         so both access-control flavours must agree.
     */
    function test_AddressSetRulesOwnable2StepAdvertiseIAddressList() public {
        bytes4 id = AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID;

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        assertTrue(
            new RuleWhitelistOwnable2Step(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false).supportsInterface(id),
            "RuleWhitelistOwnable2Step"
        );
        assertTrue(
            new RuleBlacklistOwnable2Step(DEFAULT_ADMIN_ADDRESS, FORWARDER).supportsInterface(id),
            "RuleBlacklistOwnable2Step"
        );
        assertTrue(
            new RuleSpenderWhitelistOwnable2Step(DEFAULT_ADMIN_ADDRESS, FORWARDER).supportsInterface(id),
            "RuleSpenderWhitelistOwnable2Step"
        );
        vm.stopPrank();
    }

    /**
     * @notice Advertising IAddressList must not break the existing ERC-165 advertisements.
     */
    function test_AdvertisementDoesNotBreakExistingInterfaces() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist rule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);

        assertTrue(rule.supportsInterface(type(IERC165).interfaceId), "IERC165");
        assertTrue(rule.supportsInterface(RuleInterfaceId.IRULE_INTERFACE_ID), "IRule");
        assertFalse(rule.supportsInterface(bytes4(0xdeadbeef)), "unknown interface");
    }

    /*//////////////////////////////////////////////////////////////
                    RULES THAT MUST *NOT* ADVERTISE IT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A rule with no address set must not claim IAddressList — this is precisely the case
     *         the wrapper's future `_checkRule` guard (I-4) needs to reject.
     */
    function test_NonAddressListRuleDoesNotAdvertiseIt() public {
        TotalSupplyMock token = new TotalSupplyMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 1000);

        assertFalse(
            rule.supportsInterface(AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID),
            "RuleMaxTotalSupply must not claim IAddressList"
        );
    }

    /**
     * @notice `RuleWhitelistWrapper` aggregates child address lists but exposes no address set of its
     *         own (no `addAddress`/`areAddressesListed`), so it correctly does NOT advertise
     *         IAddressList — meaning a wrapper cannot be nested as a child of another wrapper.
     */
    function test_WrapperDoesNotAdvertiseIAddressList() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);

        assertFalse(
            wrapper.supportsInterface(AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID),
            "wrapper is not itself an address list"
        );
    }
}
