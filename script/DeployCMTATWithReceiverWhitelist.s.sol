// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithReceiverWhitelist
 * @notice Deploys a CMTAT token guarded by a single `RuleReceiverWhitelist`.
 *
 *         Deployment order:
 *         1. `RuleReceiverWhitelist` — only whitelisted addresses may receive tokens
 *         2. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so it never
 *      exists without compliance and the deployer never holds a role on it.
 *
 * @dev **Topology B (direct binding).** The rule is set straight on the token. It is stateless, so it
 *      behaves the same behind a RuleEngine.
 *
 * @dev Only the receiver is screened (ERC-3643 eligibility): sender and spender are never checked,
 *      so a de-listed holder can still exit. Mints are screened on the receiver, with no
 *      `allowMint` flag; burns always pass. After deployment the admin must whitelist investors
 *      (`addAddress` / `addAddresses`) before anything can be minted to them.
 */
contract DeployCMTATWithReceiverWhitelist is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The receiver-whitelist rule set on it.
     */
    function deploy(address admin, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleReceiverWhitelist rule)
    {
        rule = new RuleReceiverWhitelist(admin, forwarder);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

        _logDeployment("CMTAT token          ", address(token));
        _logDeployment("RuleReceiverWhitelist", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration: the whitelist starts empty.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleReceiverWhitelist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
