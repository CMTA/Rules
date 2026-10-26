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
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleBlacklist`           — blocks blacklisted sender / recipient / spender
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
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
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract, and Foundry rejects
     *      `address(this)` inside a broadcast ("script contracts are ephemeral and their addresses
     *      should not be relied upon"). Reading it there made this script revert before it could
     *      deploy anything (CLAUDE_ANALYSIS_SCRIPT.md S-1).
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token.
     * @param deployer Address that executes the calls and holds the temporary admin role:
     *        `msg.sender` under `forge script`, the script contract's address under test.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The blacklist rule bound to it.
     */
    function deploy(address admin, address deployer, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleBlacklist rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleBlacklist(admin, forwarder);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

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
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
