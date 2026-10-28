// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";
import {CMTATDeploymentBase} from "script/base/CMTATDeploymentBase.sol";

/**
 * @dev Exposes the base's cap readers, which the scripts only call from `run()`. The decimals are set on the
 * harness rather than through `vm.setEnv`, which is process-wide and would leak into the deployment tests
 * running in parallel.
 */
contract CMTATDeploymentBaseHarness is CMTATDeploymentBase {
    uint8 private immutable DECIMALS;

    constructor(uint8 decimals_) {
        DECIMALS = decimals_;
    }

    function _erc20Attributes() internal view override returns (ICMTATConstructor.ERC20Attributes memory attributes) {
        attributes = ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", DECIMALS);
    }

    function maxTotalSupply() external view returns (uint256) {
        return _maxTotalSupply();
    }

    function maxBalance() external view returns (uint256) {
        return _maxBalance();
    }

    function issuanceCap() external view returns (uint256) {
        return _issuanceCap();
    }
}

/**
 * @title The deployment scripts' default caps
 * @notice With no environment value, each default is a whole-token amount scaled by the token's decimals, so it
 * stays meaningful on a token that is not 0-decimal.
 */
contract CMTATDeploymentBaseTest is Test {
    function testDefaultsAreWholeTokensAtZeroDecimals() public {
        CMTATDeploymentBaseHarness harness = new CMTATDeploymentBaseHarness(0);
        assertEq(harness.maxTotalSupply(), 1_000_000);
        assertEq(harness.maxBalance(), 100_000);
        assertEq(harness.issuanceCap(), 1_000_000);
    }

    function testDefaultsScaleWithDecimals() public {
        CMTATDeploymentBaseHarness harness = new CMTATDeploymentBaseHarness(18);
        assertEq(harness.maxTotalSupply(), 1_000_000 * 1e18);
        assertEq(harness.maxBalance(), 100_000 * 1e18);
        assertEq(harness.issuanceCap(), 1_000_000 * 1e18);
    }
}
