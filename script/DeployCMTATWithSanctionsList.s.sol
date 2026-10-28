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
 *         1. `RuleSanctionsList` — blocks sanctioned sender / recipient / spender via an oracle
 *         2. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so it never
 *      exists without compliance and the deployer never holds a role on it.
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
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param sanctionsOracle Sanctions oracle; `address(0)` leaves screening disabled (fail open).
     * @return token The deployed CMTAT.
     * @return rule The sanctions rule set on it.
     */
    function deploy(address admin, address forwarder, ISanctionsList sanctionsOracle)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleSanctionsList rule)
    {
        rule = new RuleSanctionsList(admin, forwarder, sanctionsOracle);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

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
        (token, rule) = deploy(msg.sender, _forwarder(), ISanctionsList(vm.envOr("SANCTIONS_ORACLE", address(0))));
        vm.stopBroadcast();
    }
}
