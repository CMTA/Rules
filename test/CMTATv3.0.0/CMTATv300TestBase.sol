// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleEngine} from "RuleEngine/deployment/accessControl/RuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {CMTATDeploymentV300} from "test/utils/CMTATDeploymentV300.sol";

/**
 * @notice The CMTAT v3.0.0 surface the tests drive, common to the Standard and Debt variants.
 * @dev `detectTransferRestriction*` exist on Standard only (Debt has no ERC-1404 layer); the base calls
 * them only when {CMTATv300TestBase._isDebt} is false.
 */
interface ICMTATv300 {
    function mint(address account, uint256 value) external;
    function burn(address account, uint256 value) external;
    function burnAndMint(address from, address to, uint256 amountToBurn, uint256 amountToMint, bytes calldata data)
        external;
    function forcedTransfer(address from, address to, uint256 value) external returns (bool);
    /// @dev Standard only.
    function crosschainMint(address to, uint256 value) external;
    /// @dev Standard only.
    function crosschainBurn(address from, uint256 value) external;
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function setRuleEngine(address ruleEngine_) external;
    function canTransfer(address from, address to, uint256 value) external view returns (bool);
    function canTransferFrom(address spender, address from, address to, uint256 value) external view returns (bool);
    function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        external
        view
        returns (uint8);
}

/**
 * @title CMTATv300TestBase
 * @notice Runs a rule against a real CMTAT v3.0.0 token, the last audited CMTAT release.
 * @dev Each concrete suite picks the token variant ({_isDebt}) and the topology ({_viaEngine}):
 * - direct (Topology B): `token.setRuleEngine(rule)`, so the rule is called by the token;
 * - engine (Topology A): the rule sits in a RuleEngine bound to the token.
 * On v3.0.0 mint and burn reach the rule on the 3-argument `transferred` with no spender, and
 * `transferFrom` on the 4-argument one with the caller as spender.
 */
abstract contract CMTATv300TestBase is Test, HelperContract {
    ICMTATv300 internal token;
    RuleEngine internal engine;

    /// @dev `setRuleEngine` takes the v3.0.0 `IRuleEngine`; the selector is identical for an address argument.
    bytes4 private constant SET_RULE_ENGINE = bytes4(keccak256("setRuleEngine(address)"));

    function _isDebt() internal pure virtual returns (bool);

    function _viaEngine() internal pure virtual returns (bool);

    function _deployToken() internal {
        CMTATDeploymentV300 deployer = new CMTATDeploymentV300();
        token = _isDebt()
            ? ICMTATv300(address(deployer.deployDebt(DEFAULT_ADMIN_ADDRESS)))
            : ICMTATv300(address(deployer.deployStandard(DEFAULT_ADMIN_ADDRESS)));
    }

    /**
     * @notice Installs `rule` on the token, directly or through a fresh RuleEngine.
     */
    function _attach(address rule) internal {
        address target = rule;
        if (_viaEngine()) {
            vm.startPrank(DEFAULT_ADMIN_ADDRESS);
            engine = new RuleEngine(DEFAULT_ADMIN_ADDRESS, address(token));
            engine.addRule(IRule(rule));
            vm.stopPrank();
            target = address(engine);
        }
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool ok,) = address(token).call(abi.encodeWithSelector(SET_RULE_ENGINE, target));
        require(ok, "setRuleEngine failed");
    }

    /**
     * @notice Removes the rule engine from the token (`setRuleEngine(address(0))`).
     */
    function _detach() internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool ok,) = address(token).call(abi.encodeWithSelector(SET_RULE_ENGINE, address(0)));
        require(ok, "setRuleEngine failed");
    }

    /**
     * @notice Re-installs `target` (the rule itself, or the engine already built by {_attach}).
     */
    function _reattach(address target) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        (bool ok,) = address(token).call(abi.encodeWithSelector(SET_RULE_ENGINE, target));
        require(ok, "setRuleEngine failed");
    }

    /**
     * @notice The address a stateful rule sees as `msg.sender` on its write path: the engine or the token.
     */
    function _ruleCaller() internal view returns (address) {
        return _viaEngine() ? address(engine) : address(token);
    }

    function _mint(address to, uint256 value) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.mint(to, value);
    }

    function _burn(address from, uint256 value) internal {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        token.burn(from, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        vm.prank(from);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(to, value);
    }

    function _transferFrom(address spender, address from, address to, uint256 value) internal {
        _approve(from, spender, value);
        _transferFromApproved(spender, from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        vm.prank(owner);
        token.approve(spender, value);
    }

    /// @dev No approval inside, so a preceding `vm.expect*Revert` targets the `transferFrom` itself.
    function _transferFromApproved(address spender, address from, address to, uint256 value) internal {
        vm.prank(spender);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(from, to, value);
    }

    /**
     * @notice The token's own views agree with the expected rule code. Debt exposes `canTransfer` only.
     */
    function _assertCode(address from, address to, uint256 value, uint8 code) internal view {
        assertEq(token.canTransfer(from, to, value), code == TRANSFER_OK, "canTransfer");
        if (!_isDebt()) {
            assertEq(token.detectTransferRestriction(from, to, value), code, "detectTransferRestriction");
        }
    }

    function _assertCodeFrom(address spender, address from, address to, uint256 value, uint8 code) internal view {
        assertEq(token.canTransferFrom(spender, from, to, value), code == TRANSFER_OK, "canTransferFrom");
        if (!_isDebt()) {
            assertEq(
                token.detectTransferRestrictionFrom(spender, from, to, value), code, "detectTransferRestrictionFrom"
            );
        }
    }
}
