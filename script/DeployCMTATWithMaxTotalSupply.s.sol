// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithMaxTotalSupply
 * @notice Deploys a CMTAT token guarded by a single `RuleMaxTotalSupply`.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleMaxTotalSupply`      — rejects mints that would push `totalSupply` past the cap
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** The rule is set straight on the token, with no RuleEngine in
 *      between. To combine the cap with other rules, start from
 *      `DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply` instead.
 *
 * @dev **Step 2 must follow step 1.** The rule validates its token at construction (non-zero, has
 *      code, `totalSupply()` callable), so it cannot be deployed before the token exists.
 *
 * @dev The cap is in the token's base units, compared as-is with `totalSupply()`. With the default
 *      0 decimals that is whole tokens; on an 18-decimal token pass `cap * 10**18`.
 */
contract DeployCMTATWithMaxTotalSupply is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract, and Foundry rejects
     *      `address(this)` inside a broadcast.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @param maxTotalSupply The supply ceiling enforced on mints, in base units.
     * @return token The deployed CMTAT.
     * @return rule The supply-cap rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder, uint256 maxTotalSupply)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleMaxTotalSupply rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        // MUST come after the token: the constructor probes `totalSupply()`.
        rule = new RuleMaxTotalSupply(admin, address(token), maxTotalSupply);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token       ", address(token));
        _logDeployment("RuleMaxTotalSupply", address(rule));
    }

    /**
     * @notice Broadcast entrypoint. The cap is read from `CMTAT_MAX_SUPPLY`, default 1 000 000 base units.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleMaxTotalSupply rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder(), vm.envOr("CMTAT_MAX_SUPPLY", uint256(1_000_000)));
        vm.stopBroadcast();
    }
}
