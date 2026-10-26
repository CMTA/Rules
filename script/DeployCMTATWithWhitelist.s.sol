// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithWhitelist
 * @notice Deploys a CMTAT token guarded by a single `RuleWhitelist`.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleWhitelist`           — transfers allowed only between whitelisted addresses
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** The rule is bound straight to the token, so inside the rule
 *      `msg.sender` is the token. Fine for a validation rule; not interchangeable with the
 *      RuleEngine topology for operation rules. See `CLAUDE.md`, "The two integration topologies".
 */
contract DeployCMTATWithWhitelist is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`; see
     *      `DeployCMTATWithBlacklist` and CLAUDE_ANALYSIS_SCRIPT.md S-1 for why.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param checkSpender When true, `transferFrom` also requires the spender to be whitelisted.
     * @param allowMintBurn Whether the rule permits mint and burn.
     *
     *        **This decides whether the token can be issued at all.** The whitelist screens the
     *        mint/burn sentinel `address(0)` like any other participant, so with `false` every mint
     *        is rejected with code 24 (`CODE_MINT_NOT_ALLOWED`) even to a whitelisted investor. The
     *        script previously hard-coded `false` and shipped a token nobody could issue
     *        (CLAUDE_ANALYSIS_SCRIPT.md S-3); {run} now passes `true`. Recoverable either way with
     *        `setAllowMint` / `setAllowBurn`, gated on `DEFAULT_ADMIN_ROLE`.
     * @return token The deployed CMTAT.
     * @return rule The whitelist rule bound to it.
     */
    function deploy(address admin, address deployer, address forwarder, bool checkSpender, bool allowMintBurn)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleWhitelist rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleWhitelist(admin, forwarder, checkSpender, allowMintBurn);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token  ", address(token));
        _logDeployment("RuleWhitelist", address(rule));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev Deploys with spender checks off and mint/burn allowed, so the token can be issued
     *      immediately. Addresses still have to be whitelisted before any transfer succeeds.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleWhitelist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder(), false, true);
        vm.stopBroadcast();
    }
}
