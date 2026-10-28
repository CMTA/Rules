// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithERC2980
 * @notice Deploys a CMTAT token guarded by a single `RuleERC2980` (ERC-2980 Swiss Compliant).
 *
 *         Deployment order:
 *         1. `RuleERC2980` — receiver whitelist plus a frozenlist (sender, receiver, spender)
 *         2. `CMTATStandardStandalone` — the token, created with `admin` and the rule in its constructor
 *
 * @dev The token is created with `admin` as its admin and the rule already installed, so it never
 *      exists without compliance and the deployer never holds a role on it.
 *
 * @dev **Topology B (direct binding).** The rule is set straight on the token, no RuleEngine.
 *
 * @dev **After deployment** the whitelist is empty, so every mint and transfer is rejected with
 *      code 63 until the admin (or a `WHITELIST_ADD_ROLE` holder) calls `addWhitelistAddresses`.
 *      The rule's frozenlist is separate from the token's own freeze (`ENFORCER_ROLE`). On CMTAT
 *      v3.3 the minter arrives as the spender and is screened against the frozenlist.
 */
contract DeployCMTATWithERC2980 is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token and its rule.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param forwarder ERC-2771 trusted forwarder for the token and the rule; `address(0)` disables it.
     * @param allowMintBurn Whether the rule permits mint and burn. With `false` every mint is rejected
     *        with code 64 and every burn with code 65; changeable later with `setAllowMint` / `setAllowBurn`.
     * @return token The deployed CMTAT.
     * @return rule The ERC-2980 rule set on it.
     */
    function deploy(address admin, address forwarder, bool allowMintBurn)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleERC2980 rule)
    {
        rule = new RuleERC2980(admin, forwarder, allowMintBurn);

        // The token takes `admin` and the rule in its constructor: no temporary admin to hand over.
        token = new CMTATStandardStandalone(
            forwarder, admin, _erc20Attributes(), _extraInformationAttributes(), _engine(IRuleEngine(address(rule)))
        );

        _logDeployment("CMTAT token", address(token));
        _logDeployment("RuleERC2980", address(rule));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev Mint and burn are allowed so the token can be issued once investors are whitelisted.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleERC2980 rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, _forwarder(), true);
        vm.stopBroadcast();
    }
}
