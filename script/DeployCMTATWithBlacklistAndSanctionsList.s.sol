// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleEngine2771} from "RuleEngine/deployment/accessControl/RuleEngine2771.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithBlacklistAndSanctionsList
 * @notice Deploys a CMTAT token behind a RuleEngine enforcing two validation rules: a blacklist and
 *         sanctions screening.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleBlacklist`           — blocks blacklisted sender / recipient / spender
 *         3. `RuleSanctionsList`       — blocks sanctioned addresses via a Chainalysis-style oracle
 *         4. `RuleEngine`              — aggregates both; the token is bound at construction
 *         5. `token.setRuleEngine(...)`
 *         6. Hand every admin role to `admin`, renounce the deployer's
 *
 * @dev **Topology A (RuleEngine).** Rules are reached through the engine, so inside a rule
 *      `msg.sender` is the RuleEngine rather than the token. See `CLAUDE.md`, "The two integration
 *      topologies", before adding an operation rule here.
 *
 * @dev Rule order affects only *which* restriction code a rejected transfer reports (the engine
 *      returns the first non-zero code), not whether it is rejected.
 */
contract DeployCMTATWithBlacklistAndSanctionsList is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the whole set.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes these calls, and Foundry rejects `address(this)` inside a broadcast, so
     *      the previous version reverted before deploying anything (CLAUDE_ANALYSIS_SCRIPT.md S-1).
     * @param admin Address that ends up holding every admin role.
     * @param deployer Address that executes the calls and holds the temporary admin roles:
     *        `msg.sender` under `forge script`, the script contract's address under test.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param sanctionsOracle Sanctions oracle. `address(0)` leaves screening disabled until
     *        `RuleSanctionsList.setSanctionListOracle` is called. **An unset oracle fails OPEN** —
     *        the rule is registered, the engine reports no error, and every transfer passes it.
     * @return token The deployed CMTAT.
     * @return ruleEngine The engine holding both rules.
     * @return ruleBlacklist The blacklist rule.
     * @return ruleSanctionsList The sanctions rule.
     */
    function deploy(address admin, address deployer, address forwarder, ISanctionsList sanctionsOracle)
        public
        virtual
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList
        )
    {
        // 1. The token, with the deployer as temporary admin so the wiring below is permitted.
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );

        // 2-3. Address-screening rules; each is owned by the intended admin from the start.
        ruleBlacklist = new RuleBlacklist(admin, forwarder);
        ruleSanctionsList = new RuleSanctionsList(admin, forwarder, sanctionsOracle);

        // 4. The engine, deployer-owned for now so rules can be added. Binding the token at
        //    construction is what authorises it to call `transferred()` on the engine.
        //    ERC-2771 is opt-in since RuleEngine v3.0.0-rc7: only the `2771` variant takes a forwarder.
        ruleEngine = forwarder == address(0)
            ? new RuleEngine(deployer, address(token))
            : new RuleEngine2771(deployer, forwarder, address(token));
        ruleEngine.addRule(ruleBlacklist);
        ruleEngine.addRule(ruleSanctionsList);

        // 5. Connect the engine to the token.
        token.setRuleEngine(IRuleEngine(address(ruleEngine)));

        // 6. Hand over, and drop the deployer's rights so the deployment key is not a standing risk.
        if (admin != deployer) {
            ruleEngine.grantRole(ruleEngine.DEFAULT_ADMIN_ROLE(), admin);
            ruleEngine.renounceRole(ruleEngine.DEFAULT_ADMIN_ROLE(), deployer);
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token      ", address(token));
        _logDeployment("RuleEngine       ", address(ruleEngine));
        _logDeployment("RuleBlacklist    ", address(ruleBlacklist));
        _logDeployment("RuleSanctionsList", address(ruleSanctionsList));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev The oracle is left unset because its address is chain-specific (Chainalysis publishes one
     *      per network). **Until it is set, sanctions screening passes everything** — call
     *      `setSanctionListOracle` before the token goes live, or set `SANCTIONS_ORACLE`.
     */
    function run()
        external
        virtual
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList
        )
    {
        vm.startBroadcast();
        (token, ruleEngine, ruleBlacklist, ruleSanctionsList) =
            deploy(msg.sender, msg.sender, _forwarder(), ISanctionsList(vm.envOr("SANCTIONS_ORACLE", address(0))));
        vm.stopBroadcast();
    }
}
