// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithMintAllowance
 * @notice Deploys a CMTAT token whose mints are debited from a per-minter quota.
 *
 *         Deployment order:
 *         1. `RuleMintAllowance` — with `deployer` as temporary admin
 *         2. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *         3. `rule.bindToken(token)` — the token is the caller in direct mode
 *         4. Hand `DEFAULT_ADMIN_ROLE` on the rule to `admin`, renounce the deployer's
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so the deployer
 *      never holds a role on it. Only the rule needs a temporary admin, for the `bindToken` call.
 *
 * @dev **Topology B (direct binding).** Requires CMTAT >= v3.3, which passes the minter as `spender`.
 * @dev **No quota is set: every mint is refused until the operator calls `setMintAllowance`** (with
 *      `ALLOWANCE_OPERATOR_ROLE`), including for `admin`, who is NOT exempt. Pre-flight a mint with
 *      `detectTransferRestrictionFrom(minter, address(0), to, value)`; `detectTransferRestriction`
 *      cannot see the minter and always answers 0.
 */
contract DeployCMTATWithMintAllowance is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role on the rule.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @return token The deployed CMTAT.
     * @return rule The mint-quota rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleMintAllowance rule)
    {
        rule = new RuleMintAllowance(deployer);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

        rule.bindToken(address(token));

        // The rule was created with the deployer as admin only so it could call `bindToken` above.
        // Skipped when both are the same address: the renounce would then remove the only admin.
        if (admin != deployer) {
            rule.grantRole(rule.DEFAULT_ADMIN_ROLE(), admin);
            rule.renounceRole(rule.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token      ", address(token));
        _logDeployment("RuleMintAllowance", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. No rule-specific configuration; quotas are set afterwards.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleMintAllowance rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder());
        vm.stopBroadcast();
    }
}
