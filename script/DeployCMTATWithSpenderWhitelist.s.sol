// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithSpenderWhitelist
 * @notice Deploys a CMTAT token guarded by a single `RuleSpenderWhitelist`.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleSpenderWhitelist`    — `transferFrom` only by a whitelisted spender
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** The rule is set straight on the token.
 *
 * @dev WARNING: the rule acts **only on `transferFrom`**. Direct transfers, mints and burns always
 *      pass, so on its own this token screens no holder at all. It should normally be combined,
 *      behind a RuleEngine, with a rule that screens holders (`RuleWhitelist`,
 *      `RuleReceiverWhitelist`, `RuleIdentityRegistry`). After deployment the admin must whitelist
 *      the permitted spenders (`addAddress`), or every `transferFrom` is rejected (code 66).
 */
contract DeployCMTATWithSpenderWhitelist is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract, and Foundry rejects
     *      `address(this)` inside a broadcast.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The spender-whitelist rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleSpenderWhitelist rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleSpenderWhitelist(admin, forwarder);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token         ", address(token));
        _logDeployment("RuleSpenderWhitelist", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration: the spender list starts empty.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleSpenderWhitelist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
