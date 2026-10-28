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
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleReceiverWhitelist`   — only whitelisted addresses may receive tokens
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
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
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract, and Foundry rejects
     *      `address(this)` inside a broadcast.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The receiver-whitelist rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleReceiverWhitelist rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleReceiverWhitelist(admin, forwarder);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token          ", address(token));
        _logDeployment("RuleReceiverWhitelist", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration: the whitelist starts empty.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleReceiverWhitelist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
