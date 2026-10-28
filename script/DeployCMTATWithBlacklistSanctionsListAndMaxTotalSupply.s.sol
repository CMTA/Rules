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
 *         1. `RuleBlacklist` — blocks blacklisted sender / recipient / spender
 *         2. `RuleSanctionsList` — blocks sanctioned addresses via a Chainalysis-style oracle
 *         3. `RuleEngine` — no token yet, `deployer` as temporary admin
 *         4. `CMTATStandardStandalone` — the token, created with `admin` and the engine in its constructor
 *         5. `RuleMaxTotalSupply` — rejects mints that would push `totalSupply` past the cap
 *         6. `addRule` the three rules, then `ruleEngine.bindToken(token)` last
 *         7. Hand `DEFAULT_ADMIN_ROLE` on the engine to `admin`, renounce the deployer's
 *
 * @dev **Step 5 must follow step 4.** Unlike the other two rules, `RuleMaxTotalSupply` validates its
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
        // 1-2. Address-screening rules; each is owned by the intended admin from the start.
        ruleBlacklist = new RuleBlacklist(admin, forwarder);
        ruleSanctionsList = new RuleSanctionsList(admin, forwarder, sanctionsOracle);

        // 3. The engine, with no token yet. The deployer is its temporary admin so that it can add the
        //    rules and bind the token below. ERC-2771 is opt-in since RuleEngine v3.0.0-rc7: only the
        //    `2771` variant takes a forwarder.
        ruleEngine = forwarder == address(0)
            ? new RuleEngine(deployer, address(0))
            : new RuleEngine2771(deployer, forwarder, address(0));

        // 4. The token, created with `admin` and the engine in its constructor: no temporary admin on it.
        //    Until step 6 the engine rejects every call from it, so nothing moves unscreened.
        token = new CMTATStandardStandalone(
            forwarder,
            admin,
            _erc20Attributes(),
            _extraInformationAttributes(),
            _engine(IRuleEngine(address(ruleEngine)))
        );

        // 5. The supply cap. MUST come after the token: the constructor probes `totalSupply()`.
        ruleMaxTotalSupply = new RuleMaxTotalSupply(admin, address(token), maxTotalSupply);
        ruleEngine.addRule(ruleBlacklist);
        ruleEngine.addRule(ruleSanctionsList);
        ruleEngine.addRule(ruleMaxTotalSupply);

        // 6. Bind the token last: from now on it may call `transferred()` on the engine.
        ruleEngine.bindToken(address(token));

        // 7. Hand the engine over. Skipped when both are the same address: the renounce would then
        //    remove the only admin.
        if (admin != deployer) {
            ruleEngine.grantRole(ruleEngine.DEFAULT_ADMIN_ROLE(), admin);
            ruleEngine.renounceRole(ruleEngine.DEFAULT_ADMIN_ROLE(), deployer);
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
