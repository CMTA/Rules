// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;


interface IIdentityRegistryVerified {
    // registry consultation
    function isVerified(address _userAddress) external view returns (bool);
}

interface IIdentityRegistryContains {
    // registry consultation
    function contains(address _userAddress) external view returns (bool);
}