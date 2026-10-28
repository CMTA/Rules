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
 *         1. `RuleSpenderWhitelist` — `transferFrom` only by a whitelisted spender
 *         2. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so it never
 *      exists without compliance and the deployer never holds a role on it.
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
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The spender-whitelist rule set on it.
     */
    function deploy(address admin, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleSpenderWhitelist rule)
    {
        rule = new RuleSpenderWhitelist(admin, forwarder);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

        _logDeployment("CMTAT token         ", address(token));
        _logDeployment("RuleSpenderWhitelist", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration: the spender list starts empty.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleSpenderWhitelist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
