// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleMaxBalance} from "src/rules/validation/deployment/RuleMaxBalance.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithMaxBalance
 * @notice Deploys a CMTAT token guarded by a single `RuleMaxBalance`.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleMaxBalance`          — caps the balance any one receiver may reach (burns exempt)
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** Step 2 must follow step 1: the rule validates its token.
 *
 * @dev WARNING: the cap is per address, so it is **bypassable by splitting a position across
 *      wallets**. Combine it with a rule admitting one address per investor (`RuleWhitelist`,
 *      `RuleReceiverWhitelist`, `RuleIdentityRegistry`) behind a RuleEngine, under a one-address-per-
 *      entity onboarding policy. Used alone, as here, that guarantee must come from another control.
 *
 * @dev Env: `CMTAT_MAX_BALANCE`, default 100 000 base units. `maxBalance = 0` forbids holding, it
 *      does not disable the rule. **After deployment**, exempt the treasury or custodian that must
 *      hold more than the cap with `addExemptAddresses` (`MAX_BALANCE_ROLE`).
 */
contract DeployCMTATWithMaxBalance is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @param maxBalance The largest balance a non-exempt address may hold, in base units.
     * @return token The deployed CMTAT.
     * @return rule The balance-cap rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder, uint256 maxBalance)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleMaxBalance rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        // MUST come after the token: the constructor probes `balanceOf`.
        rule = new RuleMaxBalance(admin, address(token), maxBalance);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token   ", address(token));
        _logDeployment("RuleMaxBalance", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. The cap is read from `CMTAT_MAX_BALANCE`, default 100 000 base units.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleMaxBalance rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder(), vm.envOr("CMTAT_MAX_BALANCE", uint256(100_000)));
        vm.stopBroadcast();
    }
}
