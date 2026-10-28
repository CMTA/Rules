// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {RuleEngine2771} from "RuleEngine/deployment/accessControl/RuleEngine2771.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply
 * @notice Deploys a CMTAT token behind a RuleEngine enforcing three validation rules: a blacklist,
 *         sanctions screening, and a hard cap on total supply.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token (deployer as temporary admin, so it can be wired)
 *         2. `RuleBlacklist`           — blocks blacklisted sender / recipient / spender
 *         3. `RuleSanctionsList`       — blocks sanctioned addresses via a Chainalysis-style oracle
 *         4. `RuleMaxTotalSupply`      — rejects mints that would push `totalSupply` past the cap
 *         5. `RuleEngine`              — aggregates all three; the token is bound at construction
 *         6. `token.setRuleEngine(...)`
 *         7. Hand every admin role to `admin`, renounce the deployer's
 *
 * @dev **Step 4 must follow step 1.** Unlike the other two rules, `RuleMaxTotalSupply` validates its
 *      token at construction — non-zero, has code, and `totalSupply()` callable — so it cannot be
 *      deployed before the token exists. Passing a placeholder address reverts with
 *      `RuleMaxTotalSupply_TokenIsNotAContract`.
 *
 * @dev **One `RuleMaxTotalSupply` instance protects one token.** It reads `totalSupply()` from the
 *      `tokenContract` it was given, never from whichever token triggered the check, and behind a
 *      RuleEngine it cannot learn that identity. Do not add this instance to a second RuleEngine:
 *      both tokens would be capped against this one's supply. Deploy a second instance instead.
 *
 * @dev Rule order matters only for *which* restriction code a rejected transfer reports — the
 *      RuleEngine returns the first non-zero code — not for whether it is rejected. Blacklist first,
 *      then sanctions, then the supply cap, so an address-level rejection is reported in preference
 *      to a supply-level one.
 */
contract DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the whole set.
     * @dev `deployer` is passed explicitly rather than read as `address(this)`, because the two
     *      execution contexts disagree about who makes the wiring calls: under `forge script` the
     *      broadcaster does, while a test calling {deploy} directly makes them from the script
     *      contract. Foundry also *rejects* `address(this)` inside a broadcast outright — "script
     *      contracts are ephemeral and their addresses should not be relied upon" — so a script that
     *      reads it works under test and reverts on the real deployment path.
     * @param admin Address that ends up holding every admin role.
     * @param deployer Address that executes the calls below and therefore holds the temporary admin
     *        roles: `msg.sender` under `forge script`, the script contract's address under test.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param sanctionsOracle Sanctions oracle; `address(0)` leaves screening disabled until
     *        `RuleSanctionsList.setSanctionListOracle` is called. **An unset oracle fails OPEN** —
     *        the rule passes every transfer.
     * @param maxTotalSupply The supply ceiling enforced on mints.
     * @return token The deployed CMTAT.
     * @return ruleEngine The engine holding the three rules.
     * @return ruleBlacklist The blacklist rule.
     * @return ruleSanctionsList The sanctions rule.
     * @return ruleMaxTotalSupply The supply-cap rule.
     */
    function deploy(
        address admin,
        address deployer,
        address forwarder,
        ISanctionsList sanctionsOracle,
        uint256 maxTotalSupply
    )
        public
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList,
            RuleMaxTotalSupply ruleMaxTotalSupply
        )
    {
        // 1. The token, with the deployer as temporary admin so the wiring below is permitted.
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );

        // 2-3. Address-screening rules; each is owned by the intended admin from the start.
        ruleBlacklist = new RuleBlacklist(admin, forwarder);
        ruleSanctionsList = new RuleSanctionsList(admin, forwarder, sanctionsOracle);

        // 4. The supply cap. MUST come after the token: the constructor probes `totalSupply()`.
        ruleMaxTotalSupply = new RuleMaxTotalSupply(admin, address(token), maxTotalSupply);

        // 5. The engine, deployer-owned for now so rules can be added. Binding the token at
        //    construction is what authorises it to call `transferred()` on the engine.
        //    ERC-2771 is opt-in since RuleEngine v3.0.0-rc7: only the `2771` variant takes a forwarder.
        ruleEngine = forwarder == address(0)
            ? new RuleEngine(deployer, address(token))
            : new RuleEngine2771(deployer, forwarder, address(token));

        ruleEngine.addRule(ruleBlacklist);
        ruleEngine.addRule(ruleSanctionsList);
        ruleEngine.addRule(ruleMaxTotalSupply);

        // 6. Connect the engine to the token.
        token.setRuleEngine(IRuleEngine(address(ruleEngine)));

        // 7. Hand over, and drop the deployer's rights so the deployment key is not a standing risk.
        if (admin != deployer) {
            ruleEngine.grantRole(ruleEngine.DEFAULT_ADMIN_ROLE(), admin);
            ruleEngine.renounceRole(ruleEngine.DEFAULT_ADMIN_ROLE(), deployer);
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token       ", address(token));
        _logDeployment("RuleEngine        ", address(ruleEngine));
        _logDeployment("RuleBlacklist     ", address(ruleBlacklist));
        _logDeployment("RuleSanctionsList ", address(ruleSanctionsList));
        _logDeployment("RuleMaxTotalSupply", address(ruleMaxTotalSupply));
    }

    /**
     * @notice Broadcast entrypoint. Deploys with no sanctions oracle and the cap from `CMTAT_MAX_SUPPLY`
     *         (default 1 000 000 whole tokens).
     * @dev The oracle is left unset because its address is chain-specific (Chainalysis publishes one
     *      per network). **Until it is set, sanctions screening is disabled and passes everything** —
     *      call `setSanctionListOracle` before the token goes live.
     */
    function run()
        external
        virtual
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList,
            RuleMaxTotalSupply ruleMaxTotalSupply
        )
    {
        vm.startBroadcast();
        // The broadcaster is both the final admin and the acting deployer, so the hand-over below
        // is a no-op and no temporary rights outlive the transaction.
        (token, ruleEngine, ruleBlacklist, ruleSanctionsList, ruleMaxTotalSupply) = deploy(
            msg.sender,
            msg.sender,
            _forwarder(),
            ISanctionsList(vm.envOr("SANCTIONS_ORACLE", address(0))),
            _maxTotalSupply()
        );
        vm.stopBroadcast();
    }
}
