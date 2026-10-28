// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithConditionalTransferLight
 * @notice Deploys a CMTAT token on which every transfer needs a prior operator approval.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone`      — the token, with `deployer` as temporary admin
 *         2. `RuleConditionalTransferLight` — with `deployer` as temporary admin
 *         3. `rule.bindToken(token)`        — the token is the caller in direct mode
 *         4. `token.setRuleEngine(rule)`
 *         5. Hand `DEFAULT_ADMIN_ROLE` on the token and the rule to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** The rule is bound to exactly one token.
 * @dev After deployment: grant `OPERATOR_ROLE` to whoever approves transfers (`approveTransfer`).
 *      Each approval is consumed by one matching transfer; mints and burns need none.
 *      `approveAndTransferIfAllowed` also needs `OPERATOR_ROLE`, plus an ERC-20 allowance from
 *      `from` to the rule.
 */
contract DeployCMTATWithConditionalTransferLight is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin roles.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The approval rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleConditionalTransferLight rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleConditionalTransferLight(deployer);

        // Direct mode: the token itself calls `transferred`, so it is the caller to bind.
        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            rule.grantRole(rule.DEFAULT_ADMIN_ROLE(), admin);
            rule.renounceRole(rule.DEFAULT_ADMIN_ROLE(), deployer);
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token                 ", address(token));
        _logDeployment("RuleConditionalTransferLight", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleConditionalTransferLight rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
