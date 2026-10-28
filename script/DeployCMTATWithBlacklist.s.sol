// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithBlacklist
 * @notice Deploys a CMTAT token guarded by a single `RuleBlacklist`.
 *
 *         Deployment order:
 *         1. `RuleBlacklist` — blocks blacklisted sender / recipient / spender
 *         2. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so it never
 *      exists without compliance and the deployer never holds a role on it.
 *
 * @dev **Topology B (direct binding).** The rule is bound straight to the token, with no RuleEngine
 *      in between, so inside the rule `msg.sender` is the token itself. That is fine for a
 *      validation rule such as this one. It is *not* interchangeable with the RuleEngine topology
 *      for operation rules: see `CLAUDE.md`, "The two integration topologies". If you extend this
 *      script with a second rule you need a RuleEngine; start from
 *      `DeployCMTATWithBlacklistAndSanctionsList` instead.
 */
contract DeployCMTATWithBlacklist is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The blacklist rule bound to it.
     */
    function deploy(address admin, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleBlacklist rule)
    {
        rule = new RuleBlacklist(admin, forwarder);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

        _logDeployment("CMTAT token  ", address(token));
        _logDeployment("RuleBlacklist", address(rule));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev The broadcaster is both the final admin and the acting deployer, so the hand-over is a
     *      no-op and no temporary rights outlive the transaction.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleBlacklist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
