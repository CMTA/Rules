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
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. `RuleERC2980`             — receiver whitelist plus a frozenlist (sender, receiver, spender)
 *         3. `token.setRuleEngine(rule)`
 *         4. Hand `DEFAULT_ADMIN_ROLE` to `admin`, renounce the deployer's
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
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on the token and the rule.
     * @param deployer Address that executes the calls and holds the temporary admin role.
     * @param forwarder ERC-2771 trusted forwarder for the token and the rule; `address(0)` disables it.
     * @param allowMintBurn Whether the rule permits mint and burn. With `false` every mint is rejected
     *        with code 64 and every burn with code 65; changeable later with `setAllowMint` / `setAllowBurn`.
     * @return token The deployed CMTAT.
     * @return rule The ERC-2980 rule set on it.
     */
    function deploy(address admin, address deployer, address forwarder, bool allowMintBurn)
        public
        virtual
        returns (CMTATStandardStandalone token, RuleERC2980 rule)
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        rule = new RuleERC2980(admin, forwarder, allowMintBurn);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != deployer) {
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token", address(token));
        _logDeployment("RuleERC2980", address(rule));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev Mint and burn are allowed so the token can be issued once investors are whitelisted.
     */
    function run() external virtual returns (CMTATStandardStandalone token, RuleERC2980 rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, msg.sender, _forwarder(), true);
        vm.stopBroadcast();
    }
}
