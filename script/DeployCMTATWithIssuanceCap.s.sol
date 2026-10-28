// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleIssuanceCap} from "src/rules/operation/RuleIssuanceCap.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithIssuanceCap
 * @notice Deploys a CMTAT token with a non-replenishing lifetime issuance cap: burns never free room.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleIssuanceCap`         — after the token, `initialIssued = 0`, `deployer` as temporary admin
 *         3. `rule.bindToken(token)`   — the token is the caller in direct mode
 *         4. `token.setRuleEngine(rule)`
 *         5. Hand `DEFAULT_ADMIN_ROLE` on the token and the rule to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** One rule per token: the observed token is locked
 *      (`setTokenContract` always reverts) and the rule accepts a single binding.
 * @dev **Not for bridged tokens:** a burn-and-remint cycle consumes the budget twice. For a replenishing
 *      cap use `RuleMaxTotalSupply`. Every step runs in one call, so no mint escapes the counter.
 * @dev Env: `CMTAT_ISSUANCE_CAP` in base units (default 1 000 000 whole tokens). To raise it later the admin uses
 *      `increaseMaxTotalSupply` (`MAX_TOTAL_SUPPLY_ROLE`).
 */
contract DeployCMTATWithIssuanceCap is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin roles.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @param issuanceCap The lifetime issuance ceiling, in base units.
     * @return token The deployed CMTAT.
     * @return rule The issuance-cap rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder, uint256 issuanceCap)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleIssuanceCap rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        // MUST come after the token: the constructor probes `totalSupply()`. A new token has issued nothing.
        rule = new RuleIssuanceCap(deployer, address(token), issuanceCap, 0);

        rule.bindToken(address(token));
        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            rule.grantRole(rule.DEFAULT_ADMIN_ROLE(), admin);
            rule.renounceRole(rule.DEFAULT_ADMIN_ROLE(), deployer);
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token    ", address(token));
        _logDeployment("RuleIssuanceCap", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. The cap is read from `CMTAT_ISSUANCE_CAP`, default 1 000 000 whole tokens.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleIssuanceCap rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder(), _issuanceCap());
        vm.stopBroadcast();
    }
}
