// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";

/**
 * @title CMTATDeploymentBase
 * @notice Shared token metadata and helpers for the deployment scripts in `script/`.
 *
 * @dev Every script used to repeat the same token-attribute block verbatim, so a CMTAT constructor
 *      change meant editing each one and the failure mode of missing one was a script that still
 *      compiled. The block lives here instead (CLAUDE_ANALYSIS_SCRIPT.md S-4).
 *
 * @dev Values are read from the environment with the previous hard-coded constants as fallbacks, so
 *      the scripts stay runnable with no configuration while a real deployment no longer requires
 *      editing source (CLAUDE_ANALYSIS_SCRIPT.md S-5):
 *
 *      | Variable | Default |
 *      | --- | --- |
 *      | `CMTAT_NAME` | `CMTA Token` |
 *      | `CMTAT_SYMBOL` | `CMTAT` |
 *      | `CMTAT_DECIMALS` | `0` (Swiss-law compliant per the CMTAT specification) |
 *      | `CMTAT_TOKEN_ID` | `CMTAT_ISIN` |
 *      | `CMTAT_TERMS_NAME` | `Terms` |
 *      | `CMTAT_TERMS_URI` | `https://cmta.ch` |
 *      | `CMTAT_TERMS_HASH` | the example document hash |
 *      | `CMTAT_INFORMATION` | `CMTAT_info` |
 *      | `CMTAT_FORWARDER` | `address(0)` (meta-transactions disabled) |
 *      | `CMTAT_MAX_SUPPLY` | 1 000 000 whole tokens |
 *      | `CMTAT_MAX_BALANCE` | 100 000 whole tokens |
 *      | `CMTAT_ISSUANCE_CAP` | 1 000 000 whole tokens |
 *
 *      The three cap variables are read in base units; their defaults are whole tokens scaled by the
 *      token's decimals, so a default stays meaningful when `CMTAT_DECIMALS` is not 0.
 *
 * @dev A script needing different metadata overrides {_erc20Attributes} or
 *      {_extraInformationAttributes} rather than copying the block again.
 */
abstract contract CMTATDeploymentBase is Script {
    /**
     * @dev The example terms hash carried by every script before this base existed. Kept as the
     *      default so behaviour is unchanged when `CMTAT_TERMS_HASH` is not set.
     */
    bytes32 internal constant DEFAULT_TERMS_HASH = 0x9ff867f6592aa9d6d039e7aad6bd71f1659720cbc4dd9eae1554f6eab490098b;

    /**
     * @dev Default caps in whole tokens, scaled by {_wholeTokens} when read.
     */
    uint256 internal constant DEFAULT_MAX_TOTAL_SUPPLY_TOKENS = 1e6;
    uint256 internal constant DEFAULT_MAX_BALANCE_TOKENS = 1e5;
    uint256 internal constant DEFAULT_ISSUANCE_CAP_TOKENS = 1e6;

    /**
     * @notice Name, symbol and decimals for the token being deployed.
     * @return attributes The ERC-20 attribute struct passed to the CMTAT constructor.
     */
    function _erc20Attributes() internal view virtual returns (ICMTATConstructor.ERC20Attributes memory attributes) {
        attributes = ICMTATConstructor.ERC20Attributes({
            name: vm.envOr("CMTAT_NAME", string("CMTA Token")),
            symbol: vm.envOr("CMTAT_SYMBOL", string("CMTAT")),
            decimalsIrrevocable: uint8(vm.envOr("CMTAT_DECIMALS", uint256(0)))
        });
    }

    /**
     * @notice Identifier, terms document and free-form information for the token.
     * @return attributes The extra-information struct passed to the CMTAT constructor.
     */
    function _extraInformationAttributes()
        internal
        view
        virtual
        returns (ICMTATConstructor.ExtraInformationAttributes memory attributes)
    {
        attributes = ICMTATConstructor.ExtraInformationAttributes({
            tokenId: vm.envOr("CMTAT_TOKEN_ID", string("CMTAT_ISIN")),
            terms: IERC1643CMTAT.DocumentInfo({
                name: vm.envOr("CMTAT_TERMS_NAME", string("Terms")),
                uri: vm.envOr("CMTAT_TERMS_URI", string("https://cmta.ch")),
                documentHash: vm.envOr("CMTAT_TERMS_HASH", DEFAULT_TERMS_HASH)
            }),
            information: vm.envOr("CMTAT_INFORMATION", string("CMTAT_info"))
        });
    }

    /**
     * @notice The engine slot passed at construction.
     * @dev Always empty. Every script wires the engine (or the rule, in direct-binding mode) after
     *      deployment with `setRuleEngine`, because the engine has to know the token address and the
     *      token has to exist first.
     * @return engines A struct holding the zero rule engine.
     */
    function _emptyEngine() internal pure virtual returns (ICMTATConstructor.Engine memory engines) {
        engines = ICMTATConstructor.Engine(IRuleEngine(address(0)));
    }

    /**
     * @notice ERC-2771 trusted forwarder to install on the token and every rule.
     * @dev `address(0)` disables meta-transactions.
     * @return forwarder The configured forwarder.
     */
    function _forwarder() internal view virtual returns (address forwarder) {
        forwarder = vm.envOr("CMTAT_FORWARDER", address(0));
    }

    /**
     * @notice Supply cap for the scripts deploying `RuleMaxTotalSupply`, in base units.
     * @return cap `CMTAT_MAX_SUPPLY`, or the default of 1 000 000 whole tokens.
     */
    function _maxTotalSupply() internal view virtual returns (uint256 cap) {
        cap = vm.envOr("CMTAT_MAX_SUPPLY", _wholeTokens(DEFAULT_MAX_TOTAL_SUPPLY_TOKENS));
    }

    /**
     * @notice Per-address cap for the script deploying `RuleMaxBalance`, in base units.
     * @return cap `CMTAT_MAX_BALANCE`, or the default of 100 000 whole tokens.
     */
    function _maxBalance() internal view virtual returns (uint256 cap) {
        cap = vm.envOr("CMTAT_MAX_BALANCE", _wholeTokens(DEFAULT_MAX_BALANCE_TOKENS));
    }

    /**
     * @notice Cumulative issuance cap for the script deploying `RuleIssuanceCap`, in base units.
     * @return cap `CMTAT_ISSUANCE_CAP`, or the default of 1 000 000 whole tokens.
     */
    function _issuanceCap() internal view virtual returns (uint256 cap) {
        cap = vm.envOr("CMTAT_ISSUANCE_CAP", _wholeTokens(DEFAULT_ISSUANCE_CAP_TOKENS));
    }

    /**
     * @notice Converts whole tokens to base units with the decimals the token will be deployed with.
     * @param amount Whole tokens.
     * @return baseUnits `amount * 10 ** decimals`.
     */
    function _wholeTokens(uint256 amount) internal view virtual returns (uint256 baseUnits) {
        baseUnits = amount * 10 ** _erc20Attributes().decimalsIrrevocable;
    }

    /**
     * @notice Prints a labelled deployed address.
     * @dev `forge script` prints return values positionally, which is unreadable once a script
     *      returns five contracts. Labelling them makes the run output usable as a deployment record
     *      (CLAUDE_ANALYSIS_SCRIPT.md S-8).
     * @param label Human-readable contract name.
     * @param deployed The deployed address.
     */
    function _logDeployment(string memory label, address deployed) internal view virtual {
        console.log(label, deployed);
    }
}
