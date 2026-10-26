//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {ICMTATConstructor, CMTATStandalone} from "CMTATv3.0.0/deployment/CMTATStandalone.sol";
import {CMTATStandaloneDebt} from "CMTATv3.0.0/deployment/debt/CMTATStandaloneDebt.sol";
import {IRuleEngine} from "CMTATv3.0.0/interfaces/engine/IRuleEngine.sol";
import {ISnapshotEngine} from "CMTATv3.0.0/interfaces/engine/ISnapshotEngine.sol";
import {IERC1643} from "CMTATv3.0.0/interfaces/engine/IDocumentEngine.sol";
import {IERC1643CMTAT} from "CMTATv3.0.0/interfaces/tokenization/draft-IERC1643CMTAT.sol";

/**
 * @title CMTATDeploymentV300
 * @notice Deploys the CMTAT v3.0.0 Standard and Debt standalone tokens, the last audited CMTAT release.
 * @dev Pinned through the `lib/CMTATv3.0.0` submodule (tag `v3.0.0`) and the `CMTATv3.0.0/` remapping. On
 * v3.0.0 every mint and burn reaches the rule engine on the 3-argument `transferred`, with no spender.
 */
contract CMTATDeploymentV300 {
    address constant ZERO_ADDRESS = address(0);

    function deployStandard(address admin) external returns (CMTATStandalone) {
        return new CMTATStandalone(ZERO_ADDRESS, admin, _erc20Attributes(), _extraInformation(), _engines());
    }

    function deployDebt(address admin) external returns (CMTATStandaloneDebt) {
        return new CMTATStandaloneDebt(admin, _erc20Attributes(), _extraInformation(), _engines());
    }

    function _erc20Attributes() internal pure returns (ICMTATConstructor.ERC20Attributes memory) {
        return ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0);
    }

    function _extraInformation() internal pure returns (ICMTATConstructor.ExtraInformationAttributes memory) {
        return ICMTATConstructor.ExtraInformationAttributes(
            "CMTAT_ISIN",
            IERC1643CMTAT.DocumentInfo(
                "Terms", "https://cmta.ch", 0x9ff867f6592aa9d6d039e7aad6bd71f1659720cbc4dd9eae1554f6eab490098b
            ),
            "CMTAT_info"
        );
    }

    function _engines() internal pure returns (ICMTATConstructor.Engine memory) {
        return
            ICMTATConstructor.Engine(IRuleEngine(ZERO_ADDRESS), ISnapshotEngine(ZERO_ADDRESS), IERC1643(ZERO_ADDRESS));
    }
}
