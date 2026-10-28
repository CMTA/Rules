// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTATv300TestBase} from "./CMTATv300TestBase.sol";

/**
 * @notice Token-variant / topology mixins. A concrete suite is `contract X is RuleSuite, <Mixin> {}`.
 */
abstract contract V300StandardDirect is CMTATv300TestBase {
    function _isDebt() internal pure override returns (bool) {
        return false;
    }

    function _viaEngine() internal pure override returns (bool) {
        return false;
    }
}

abstract contract V300StandardEngine is CMTATv300TestBase {
    function _isDebt() internal pure override returns (bool) {
        return false;
    }

    function _viaEngine() internal pure override returns (bool) {
        return true;
    }
}

abstract contract V300DebtDirect is CMTATv300TestBase {
    function _isDebt() internal pure override returns (bool) {
        return true;
    }

    function _viaEngine() internal pure override returns (bool) {
        return false;
    }
}

abstract contract V300DebtEngine is CMTATv300TestBase {
    function _isDebt() internal pure override returns (bool) {
        return true;
    }

    function _viaEngine() internal pure override returns (bool) {
        return true;
    }
}
