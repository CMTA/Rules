// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithIdentityRegistry
 * @notice Deploys a CMTAT token guarded by `RuleIdentityRegistry`, backed by an `IdentityRegistryWhitelist`.
 *
 *         Deployment order:
 *         1. `IdentityRegistryWhitelist` — the registry the rule consults (`isVerified`), owned by `admin`
 *         2. `RuleIdentityRegistry` — ERC-3643 eligibility: only the receiver must be verified
 *         3. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so it never
 *      exists without compliance and the deployer never holds a role on it.
 *
 * @dev **Topology B (direct binding).** The registry sits behind the rule, not on the token: CMTAT
 *      has no identity-registry slot, so the token never calls the registry and needs no role on it.
 *
 * @dev **After deployment** the registry is empty, so every mint and transfer is rejected with
 *      code 56 until the admin (or an `IDENTITY_REGISTRAR_ROLE` holder) calls `registerIdentity`
 *      (`identity` and `country` are discarded; `address(0)` and `0` are fine). A de-listed holder
 *      can still send: keep `checkSender = false` unless trapping lapsed investors is intended.
 */
contract DeployCMTATWithIdentityRegistry is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token, the registry and the rule.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token, the registry and the rule.
     * @param forwarder ERC-2771 trusted forwarder for the token; `address(0)` disables meta-transactions.
     * @param checkSender When true, the sender must also be verified (stricter than ERC-3643).
     * @param checkSpender When true, the spender of a `transferFrom` must also be verified; never the minter.
     * @return token The deployed CMTAT.
     * @return registry The whitelist-backed identity registry.
     * @return rule The identity rule set on the token.
     */
    function deploy(address admin, address forwarder, bool checkSender, bool checkSpender)
        public
        virtual
        returns (CMTATStandardStandalone token, IdentityRegistryWhitelist registry, RuleIdentityRegistry rule)
    {
        registry = new IdentityRegistryWhitelist(admin);
        rule = new RuleIdentityRegistry(admin, address(registry), checkSender, checkSpender);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

        _logDeployment("CMTAT token              ", address(token));
        _logDeployment("IdentityRegistryWhitelist", address(registry));
        _logDeployment("RuleIdentityRegistry     ", address(rule));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev Sender and spender checks off: ERC-3643 behaviour, only the receiver is screened.
     */
    function run()
        external
        virtual
        returns (CMTATStandardStandalone token, IdentityRegistryWhitelist registry, RuleIdentityRegistry rule)
    {
        vm.startBroadcast();
        (token, registry, rule) = deploy(msg.sender, _forwarder(), false, false);
        vm.stopBroadcast();
    }
}
