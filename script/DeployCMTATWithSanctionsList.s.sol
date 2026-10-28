// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithSanctionsList
 * @notice Deploys a CMTAT token guarded by a single `RuleSanctionsList`.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleSanctionsList`       — blocks sanctioned sender / recipient / spender via an oracle
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** The rule is set straight on the token.
 *
 * @dev WARNING: **an unset oracle fails OPEN** — the rule then passes every transfer, mint and burn.
 *      The oracle is read from `SANCTIONS_ORACLE` (default `address(0)`, because the address is
 *      chain-specific). If it was not set, the admin must call `setSanctionListOracle` before the
 *      token goes live. On CMTAT v3.3 the minter is screened too, as the mint `spender`.
 */
contract DeployCMTATWithSanctionsList is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract, and Foundry rejects
     *      `address(this)` inside a broadcast.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param sanctionsOracle Sanctions oracle; `address(0)` leaves screening disabled (fail open).
     * @return token The deployed CMTAT.
     * @return rule The sanctions rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder, ISanctionsList sanctionsOracle)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleSanctionsList rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleSanctionsList(admin, forwarder, sanctionsOracle);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token      ", address(token));
        _logDeployment("RuleSanctionsList", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. The oracle is read from `SANCTIONS_ORACLE`, default `address(0)`.
     * @dev **With the default, sanctions screening is disabled and passes everything** until
     *      `setSanctionListOracle` is called.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleSanctionsList rule) {
        vm.startBroadcast();
        (token, rule) =
            deploy(msg.sender, msg.sender, _forwarder(), ISanctionsList(vm.envOr("SANCTIONS_ORACLE", address(0))));
        vm.stopBroadcast();
    }
}
