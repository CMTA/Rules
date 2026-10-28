// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithConditionalTransferLightMultiToken
 * @notice Deploys a CMTAT token with a `RuleConditionalTransferLightMultiToken`, whose approvals are
 *         keyed `(token, from, to, value)`.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone`                — the token, with `deployer` as temporary admin
 *         2. `RuleConditionalTransferLightMultiToken` — with `deployer` as temporary admin
 *         3. `rule.bindToken(token)`
 *         4. `token.setRuleEngine(rule)`
 *         5. Hand `DEFAULT_ADMIN_ROLE` on the token and the rule to `admin`, renounce the deployer's
 *
 * @dev **Direct binding only — NEVER add this rule to a RuleEngine.** Approvals are consumed under
 *      `msg.sender`; behind an engine that is the engine, so the rule reverts or loses per-token isolation.
 * @dev One token here; the same rule can be set on further tokens, each with its own `bindToken`.
 * @dev After deployment: grant `OPERATOR_ROLE` to whoever calls `approveTransfer(token, ...)`.
 *      Pre-flight with `detectTransferRestrictionForToken`: the plain view answers 46 to any caller
 *      other than the bound token.
 */
contract DeployCMTATWithConditionalTransferLightMultiToken is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin roles.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The multi-token approval rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleConditionalTransferLightMultiToken rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleConditionalTransferLightMultiToken(deployer);

        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            rule.grantRole(rule.DEFAULT_ADMIN_ROLE(), admin);
            rule.renounceRole(rule.DEFAULT_ADMIN_ROLE(), deployer);
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token                           ", address(token));
        _logDeployment("RuleConditionalTransferLightMultiToken", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration.
     */
    function run()
        external
        virtual
        returns (CMTATStandardStandalone token, RuleConditionalTransferLightMultiToken rule)
    {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
