// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/* ==== CMTAT === */
import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643ComplianceRead} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== RuleEngine === */
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {
    IERC7943NonFungibleCompliance,
    IERC7943NonFungibleComplianceExtend
} from "../../interfaces/IERC7943NonFungibleCompliance.sol";

abstract contract RuleValidateTransfer is IERC7943NonFungibleComplianceExtend, IRule {
    /**
     * @notice Validate a transfer
     * @param from the origin address
     * @param to the destination address
     * @param tokenId ERC-721 or ERC-1155 token Id
     * @param amount to transfer, 1 for NFT
     * @return isValid => true if the transfer is valid, false otherwise
     *
     */
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount)
        public
        view
        override(IERC7943NonFungibleCompliance)
        returns (bool isValid)
    {
        // does not work without `this` keyword => "Undeclared identifier"
        return this.detectTransferRestriction(from, to, tokenId, amount)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Validate a transfer
     * @param from the origin address
     * @param to the destination address
     * @param amount to transfer
     * @return isValid => true if the transfer is valid, false otherwise
     *
     */
    function canTransfer(address from, address to, uint256 amount)
        public
        view
        override(IERC3643ComplianceRead)
        returns (bool isValid)
    {
        // does not work without `this` keyword => "Undeclared identifier"
        return this.detectTransferRestriction(from, to, amount) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7551Compliance
     */
    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC7551Compliance)
        returns (bool)
    {
        return this.detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function canTransferFrom(address spender, address from, address to, uint256 tokenId, uint256 value)
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (bool)
    {
        return canTransferFrom(spender, from, to, value);
    }


    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IRule).interfaceId;
    }
}
