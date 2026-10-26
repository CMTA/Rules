// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";

/**
 * @title ConstructorEvents
 * @notice Every configuration value assigned at deployment must be announced, so a rule that is
 *         configured once and never touched can still be reconstructed from events alone
 *         (`CLAUDE_ANALYSIS.md` C-1, C-2, C-3).
 * @dev Matched on `topic0` rather than through `vm.expectEmit` so the assertions do not depend on
 *      event-declaration visibility, and so an event that is emitted the *wrong number of times* is
 *      caught as well as one that is missing. `RuleChainlinkPoR` is included although it was already
 *      correct: it is the rule the others were made to match, and pinning it stops the convention
 *      regressing from the other direction.
 */
contract ConstructorEvents is Test, HelperContract {
    bytes32 private constant MAX_TOTAL_SUPPLY_UPDATED = keccak256("MaxTotalSupplyUpdated(uint256,uint256)");
    bytes32 private constant TOKEN_CONTRACT_UPDATED = keccak256("TokenContractUpdated(address)");
    bytes32 private constant CHECK_SPENDER_UPDATED = keccak256("CheckSpenderUpdated(bool)");
    bytes32 private constant ALLOW_MINT_UPDATED = keccak256("AllowMintUpdated(bool)");
    bytes32 private constant ALLOW_BURN_UPDATED = keccak256("AllowBurnUpdated(bool)");
    bytes32 private constant IDENTITY_REGISTRY_UPDATED = keccak256("IdentityRegistryUpdated(address)");
    bytes32 private constant IDENTITY_CHECK_SENDER_UPDATED = keccak256("IdentityCheckSenderUpdated(bool)");
    bytes32 private constant IDENTITY_CHECK_SPENDER_UPDATED = keccak256("IdentityCheckSpenderUpdated(bool)");
    bytes32 private constant RESERVES_FEED_UPDATED = keccak256("ReservesFeedUpdated(address,uint8)");
    bytes32 private constant TOKEN_METADATA_UPDATED = keccak256("TokenMetadataUpdated(address,uint8)");
    bytes32 private constant MAX_STALENESS_UPDATED = keccak256("MaxStalenessSecondsUpdated(uint256)");

    /**
     * @dev Number of recorded logs whose `topic0` matches `sig`.
     */
    function _count(Vm.Log[] memory logs, bytes32 sig) internal pure returns (uint256 n) {
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == sig) {
                ++n;
            }
        }
    }

    /**
     * @dev The single log matching `sig`; reverts the test if there is not exactly one.
     */
    function _only(Vm.Log[] memory logs, bytes32 sig) internal pure returns (Vm.Log memory found) {
        uint256 seen;
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == sig) {
                found = logs[i];
                ++seen;
            }
        }
        require(seen == 1, "expected exactly one matching log");
    }

    /*//////////////////////////////////////////////////////////////
                        C-1 — RuleMaxTotalSupply
    //////////////////////////////////////////////////////////////*/

    function testMaxTotalSupplyAnnouncesItsDeploymentConfiguration() public {
        TotalSupplyMock token = new TotalSupplyMock();

        vm.recordLogs();
        new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, address(token), 4242);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_count(logs, TOKEN_CONTRACT_UPDATED), 1, "TokenContractUpdated");
        assertEq(_count(logs, MAX_TOTAL_SUPPLY_UPDATED), 1, "MaxTotalSupplyUpdated");

        // The token address is indexed; the cap is in the data.
        assertEq(address(uint160(uint256(_only(logs, TOKEN_CONTRACT_UPDATED).topics[1]))), address(token));
        (uint256 previous, uint256 current) = abi.decode(_only(logs, MAX_TOTAL_SUPPLY_UPDATED).data, (uint256, uint256));
        assertEq(previous, 0, "no cap before construction");
        assertEq(current, 4242);
    }

    /*//////////////////////////////////////////////////////////////
                    C-2 — checkSpender on both whitelists
    //////////////////////////////////////////////////////////////*/

    function testWhitelistAnnouncesCheckSpenderAlongsideTheMintBurnFlags() public {
        vm.recordLogs();
        new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_count(logs, CHECK_SPENDER_UPDATED), 1, "CheckSpenderUpdated");
        assertEq(_count(logs, ALLOW_MINT_UPDATED), 1, "AllowMintUpdated");
        assertEq(_count(logs, ALLOW_BURN_UPDATED), 1, "AllowBurnUpdated");

        assertTrue(abi.decode(_only(logs, CHECK_SPENDER_UPDATED).data, (bool)), "checkSpender = true");
        assertFalse(abi.decode(_only(logs, ALLOW_MINT_UPDATED).data, (bool)), "allowMint = false");
    }

    function testWhitelistWrapperAnnouncesCheckSpenderAlongsideTheMintBurnFlags() public {
        vm.recordLogs();
        new RuleWhitelistWrapper(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, false, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_count(logs, CHECK_SPENDER_UPDATED), 1, "CheckSpenderUpdated");
        assertEq(_count(logs, ALLOW_MINT_UPDATED), 1, "AllowMintUpdated");
        assertEq(_count(logs, ALLOW_BURN_UPDATED), 1, "AllowBurnUpdated");

        assertFalse(abi.decode(_only(logs, CHECK_SPENDER_UPDATED).data, (bool)), "checkSpender = false");
        assertTrue(abi.decode(_only(logs, ALLOW_MINT_UPDATED).data, (bool)), "allowMint = true");
    }

    function testSetCheckSpenderStillEmitsExactlyOnce() public {
        RuleWhitelist rule = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, false, true);

        vm.recordLogs();
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setCheckSpender(true);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Moving the emit into the internal helper must not double-emit from the public setter.
        assertEq(_count(logs, CHECK_SPENDER_UPDATED), 1);
        assertTrue(abi.decode(_only(logs, CHECK_SPENDER_UPDATED).data, (bool)));
    }

    /*//////////////////////////////////////////////////////////////
                    C-3 — RuleIdentityRegistry
    //////////////////////////////////////////////////////////////*/

    function testIdentityRegistryAnnouncesAConfiguredRegistry() public {
        IdentityRegistryMock registry = new IdentityRegistryMock();

        vm.recordLogs();
        new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), true, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_count(logs, IDENTITY_REGISTRY_UPDATED), 1, "IdentityRegistryUpdated");
        assertEq(_count(logs, IDENTITY_CHECK_SENDER_UPDATED), 1, "IdentityCheckSenderUpdated");
        assertEq(_count(logs, IDENTITY_CHECK_SPENDER_UPDATED), 1, "IdentityCheckSpenderUpdated");

        assertEq(address(uint160(uint256(_only(logs, IDENTITY_REGISTRY_UPDATED).topics[1]))), address(registry));
        assertTrue(abi.decode(_only(logs, IDENTITY_CHECK_SENDER_UPDATED).data, (bool)), "checkSender = true");
    }

    function testIdentityRegistryStaysSilentWhenNoRegistryIsAssigned() public {
        vm.recordLogs();
        new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Nothing was assigned, so there is nothing to announce -- an `IdentityRegistryUpdated(0)`
        // here would be indistinguishable from a deliberate `clearIdentityRegistry()`.
        assertEq(_count(logs, IDENTITY_REGISTRY_UPDATED), 0, "no registry assigned");
        assertEq(_count(logs, IDENTITY_CHECK_SENDER_UPDATED), 1, "flags are always assigned");
        assertEq(_count(logs, IDENTITY_CHECK_SPENDER_UPDATED), 1);
    }

    /*//////////////////////////////////////////////////////////////
              Reference: the rule the others were made to match
    //////////////////////////////////////////////////////////////*/

    function testChainlinkPoRStillAnnouncesItsWholeConfiguration() public {
        TotalSupplyMock token = new TotalSupplyMock();
        AggregatorV3Mock feed = new AggregatorV3Mock(8, 1000e8);

        vm.recordLogs();
        new RuleChainlinkPoR(DEFAULT_ADMIN_ADDRESS, address(token), 0, AggregatorV3Interface(address(feed)), 3600);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_count(logs, RESERVES_FEED_UPDATED), 1, "ReservesFeedUpdated");
        assertEq(_count(logs, TOKEN_METADATA_UPDATED), 1, "TokenMetadataUpdated");
        assertEq(_count(logs, MAX_STALENESS_UPDATED), 1, "MaxStalenessSecondsUpdated");
    }
}
