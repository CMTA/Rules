// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

interface ISanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}
