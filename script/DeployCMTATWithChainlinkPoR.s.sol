// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {console} from "forge-std/console.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithChainlinkPoR
 * @notice Deploys a CMTAT token whose mints are capped by a Chainlink Proof of Reserve feed.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleChainlinkPoR`        — rejects mints pushing `totalSupply` past the reported reserves
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** Step 2 must follow step 1: the rule validates its token, and
 *      `tokenDecimals` is read from it. Transfers and burns are never blocked, only mints.
 *
 * @dev Env: `CHAINLINK_POR_FEED` (default `address(0)`), `CHAINLINK_POR_MAX_STALENESS` (default
 *      86 400 s; set it to the feed's heartbeat, 0 disables the check). WARNING: with no feed on the
 *      local chain (31337), {run} deploys an `AggregatorV3Mock` stand-in so the dry run succeeds; on
 *      any other chain it reverts. Never use that mock outside a simulation.
 *
 * @dev The rule's admin can repoint the feed, and so decides how much can be minted.
 */
contract DeployCMTATWithChainlinkPoR is CMTATDeploymentBase {
    /**
     * @notice Local chain id on which {run} substitutes a mock feed when none is configured.
     */
    uint256 internal constant LOCAL_CHAIN_ID = 31_337;

    /**
     * @notice Reserves reported by the stand-in mock feed, in whole tokens.
     */
    uint256 internal constant MOCK_RESERVES = 1e6;

    /**
     * @notice `CHAINLINK_POR_FEED` is unset on a chain where no mock may be substituted.
     * @param chainId The chain the script runs on.
     */
    error DeployCMTATWithChainlinkPoR_FeedNotConfigured(uint256 chainId);

    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @param feed The Proof of Reserve feed; must be a contract answering `decimals()`.
     * @param maxStalenessSeconds Oldest acceptable feed answer, in seconds; 0 disables the check.
     * @return token The deployed CMTAT.
     * @return rule The reserve-backed mint cap set on it.
     */
    function deploy(
        address admin,
        address deployer,
        address forwarder,
        AggregatorV3Interface feed,
        uint256 maxStalenessSeconds
    ) public virtual returns (CMTATStandardStandalone token, RuleChainlinkPoR rule) {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        // MUST come after the token: the constructor checks `decimals()` and probes `totalSupply()`.
        rule = new RuleChainlinkPoR(admin, address(token), token.decimals(), feed, maxStalenessSeconds);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token     ", address(token));
        _logDeployment("RuleChainlinkPoR", address(rule));
        _logDeployment("PoR feed        ", address(feed));
    }

    /**
     * @notice Broadcast entrypoint. Reads `CHAINLINK_POR_FEED` and `CHAINLINK_POR_MAX_STALENESS`.
     * @dev Without a feed: deploys a mock on chain 31337, reverts on any other chain.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleChainlinkPoR rule) {
        address feed = vm.envOr("CHAINLINK_POR_FEED", address(0));
        uint256 maxStaleness = vm.envOr("CHAINLINK_POR_MAX_STALENESS", uint256(1 days));
        vm.startBroadcast();
        if (feed == address(0)) {
            require(block.chainid == LOCAL_CHAIN_ID, DeployCMTATWithChainlinkPoR_FeedNotConfigured(block.chainid));
            uint8 decimals_ = _erc20Attributes().decimalsIrrevocable;
            // forge-lint: disable-next-line(unsafe-typecast)
            feed = address(new AggregatorV3Mock(decimals_, int256(MOCK_RESERVES * 10 ** decimals_)));
            console.log("WARNING: CHAINLINK_POR_FEED unset, deployed a MOCK reserve feed (local only):", feed);
        }
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder(), AggregatorV3Interface(feed), maxStaleness);
        vm.stopBroadcast();
    }
}
