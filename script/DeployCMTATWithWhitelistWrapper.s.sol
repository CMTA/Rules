// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {CMTATDeploymentBase} from "./base/CMTATDeploymentBase.sol";

/**
 * @title DeployCMTATWithWhitelistWrapper
 * @notice Deploys a CMTAT token guarded by a `RuleWhitelistWrapper` aggregating two whitelists.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token, with `deployer` as temporary admin
 *         2. Two `RuleWhitelist` children, owned by `admin` — one per whitelist operator
 *         3. `RuleWhitelistWrapper`    — `deployer` as temporary admin; an address passes if ANY child lists it
 *         4. `wrapper.addRule(childA)`, `wrapper.addRule(childB)`
 *         5. `token.setRuleEngine(wrapper)`
 *         6. Hand `DEFAULT_ADMIN_ROLE` on the token and the wrapper to `admin`, renounce the deployer's
 *
 * @dev **Topology B (direct binding).** Only the wrapper is set on the token. The children must
 *      never be set on the token nor added to a RuleEngine: they would screen on their own, and an
 *      address listed by the other child only would be rejected.
 *
 * @dev After deployment the admin grants each operator `ADDRESS_LIST_ADD_ROLE` /
 *      `ADDRESS_LIST_REMOVE_ROLE` on its own child, and investors are listed there. The children's
 *      own `checkSpender` / `allowMintBurn` flags are ignored by the wrapper; its own flags apply.
 */
contract DeployCMTATWithWhitelistWrapper is CMTATDeploymentBase {
    /**
     * @notice Deploys and wires the token, the wrapper and its two children.
     * @dev `deployer` is explicit rather than read as `address(this)`: under `forge script` the
     *      broadcaster makes the calls below, not the script contract, and Foundry rejects
     *      `address(this)` inside a broadcast.
     * @param admin Address that ends up holding `DEFAULT_ADMIN_ROLE` on every deployed contract.
     * @param deployer Address that executes the calls and holds the temporary admin roles.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param checkSpender When true, `transferFrom` also requires the spender to be listed in a child.
     * @param allowMintBurn Whether the wrapper permits mint and burn. With `false` every mint is
     *        rejected with code 24 and the token cannot be issued; recoverable with `setAllowMint`.
     * @return token The deployed CMTAT.
     * @return wrapper The wrapper set on the token.
     * @return childA The first child whitelist.
     * @return childB The second child whitelist.
     */
    function deploy(address admin, address deployer, address forwarder, bool checkSpender, bool allowMintBurn)
        public
        virtual
        returns (
            CMTATStandardStandalone token,
            RuleWhitelistWrapper wrapper,
            RuleWhitelist childA,
            RuleWhitelist childB
        )
    {
        token = new CMTATStandardStandalone(
            forwarder, deployer, _erc20Attributes(), _extraInformationAttributes(), _emptyEngine()
        );
        // Children: the flags are unused by the wrapper, so they are left off.
        childA = new RuleWhitelist(admin, forwarder, false, false);
        childB = new RuleWhitelist(admin, forwarder, false, false);

        // Deployer-owned for now so the children can be added.
        wrapper = new RuleWhitelistWrapper(deployer, forwarder, checkSpender, allowMintBurn);
        wrapper.addRule(IRule(address(childA)));
        wrapper.addRule(IRule(address(childB)));

        token.setRuleEngine(IRuleEngine(address(wrapper)));

        if (admin != deployer) {
            wrapper.grantRole(wrapper.DEFAULT_ADMIN_ROLE(), admin);
            wrapper.renounceRole(wrapper.DEFAULT_ADMIN_ROLE(), deployer);
            token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
            token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);
        }

        _logDeployment("CMTAT token         ", address(token));
        _logDeployment("RuleWhitelistWrapper", address(wrapper));
        _logDeployment("RuleWhitelist A     ", address(childA));
        _logDeployment("RuleWhitelist B     ", address(childB));
    }

    /**
     * @notice Broadcast entrypoint.
     * @dev Spender checks off and mint/burn allowed, so the token can be issued immediately.
     *      Addresses still have to be listed in a child before any mint or transfer succeeds.
     */
    function run()
        external
        virtual
        returns (
            CMTATStandardStandalone token,
            RuleWhitelistWrapper wrapper,
            RuleWhitelist childA,
            RuleWhitelist childB
        )
    {
        vm.startBroadcast();
        (token, wrapper, childA, childB) = deploy(msg.sender, msg.sender, _forwarder(), false, true);
        vm.stopBroadcast();
    }
}
