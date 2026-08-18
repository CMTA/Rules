// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ComplianceNotFollowed, Token} from "ERC3643/token/Token.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {
    RuleMaxTotalSupplyInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleMaxTotalSupplyInvariantStorage.sol";
import {RuleChainlinkPoRERC3643} from "src/rules/validation/deployment/RuleChainlinkPoRERC3643.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleMaxTotalSupplyERC3643} from "src/rules/validation/deployment/RuleMaxTotalSupplyERC3643.sol";

/**
 * @title Max total supply against the REAL vendored ERC-3643 token
 * @notice Deploys the genuine `Token` from `lib/ERC-3643/` (4.2.0-beta1) and drives it through:
 *
 *             real ERC-3643 Token ── compliance slot ──▶ RuleEngine ──▶ RuleMaxTotalSupply[ERC3643]
 *                                 └─ identity slot ────▶ IdentityRegistryWhitelist
 *
 * @dev Same accounting question as the Proof-of-Reserve suite: the token calls compliance on BOTH
 *      sides of the mint --
 *
 *      ```solidity
 *      require(_tokenCompliance.canTransfer(address(0), _to, _amount), ComplianceNotFollowed());
 *      _mint(_to, _amount);                        // supply changes HERE
 *      _tokenCompliance.created(_to, _amount);     // rule notified AFTERWARDS
 *      ```
 *
 *      -- and `RuleEngine` forwards `created` as the three-argument `transferred(address(0), to, value)`.
 *      {RuleMaxTotalSupplyERC3643} re-phases only the notification.
 *
 * @dev The last section covers the composition the documentation prescribes: {RuleChainlinkPoRERC3643}
 *      has no margin parameter, so a static ceiling is added by putting both rules in the same engine.
 *
 * @dev Run with the dedicated profile: `FOUNDRY_PROFILE=erc3643 forge test`.
 */
contract ERC3643RealTokenMaxTotalSupply is Test, RuleMaxTotalSupplyInvariantStorage {
    address private constant ADMIN = address(1);
    address private constant AGENT = address(10);
    address private constant INVESTOR = address(11);
    address private constant INVESTOR2 = address(12);

    uint256 private constant CAP = 1000;

    IdentityRegistryWhitelist private registry;
    RuleEngine private engine;
    Token private token;

    function setUp() public {
        token = new Token();

        vm.startPrank(ADMIN);
        registry = new IdentityRegistryWhitelist(ADMIN);
        engine = new RuleEngine(ADMIN, address(0), address(0));
        vm.stopPrank();

        vm.prank(ADMIN);
        engine.setTokenSelfBindingApproval(address(token), true);

        token.init(address(registry), address(engine), "Real ERC-3643 Cap", "R3643", 0, address(0));

        token.addAgent(AGENT);
        vm.prank(AGENT);
        token.unpause();

        bytes32 registrarRole = registry.IDENTITY_REGISTRAR_ROLE();
        vm.startPrank(ADMIN);
        registry.grantRole(registrarRole, AGENT);
        registry.grantRole(registrarRole, address(token));
        vm.stopPrank();

        vm.startPrank(AGENT);
        registry.registerIdentity(INVESTOR, address(0), 0);
        registry.registerIdentity(INVESTOR2, address(0), 0);
        vm.stopPrank();
    }

    function _useErc3643Rule() private returns (RuleMaxTotalSupplyERC3643 rule) {
        rule = new RuleMaxTotalSupplyERC3643(ADMIN, address(token), CAP);
        vm.prank(ADMIN);
        engine.addRule(rule);
    }

    function _useStockRule() private returns (RuleMaxTotalSupply rule) {
        rule = new RuleMaxTotalSupply(ADMIN, address(token), CAP);
        vm.prank(ADMIN);
        engine.addRule(rule);
    }

    /*//////////////////////////////////////////////////////////////
                        THE ERC-3643 VARIANT
    //////////////////////////////////////////////////////////////*/

    function testMintUpToTheCapSucceeds() public {
        _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP);

        assertEq(token.totalSupply(), CAP, "a mint of exactly the cap must land");
    }

    function testMintBeyondTheCapIsRejected() public {
        _useErc3643Rule();

        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, CAP + 1);

        assertEq(token.totalSupply(), 0);
    }

    function testIncrementalMintsShareTheSameCeiling() public {
        _useErc3643Rule();

        vm.startPrank(AGENT);
        token.mint(INVESTOR, 600);
        token.mint(INVESTOR2, 400);
        vm.stopPrank();
        assertEq(token.totalSupply(), CAP);

        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 1);
    }

    /// @notice Burning frees headroom, because the cap is on supply rather than on cumulative issuance.
    function testBurningFreesHeadroom() public {
        _useErc3643Rule();

        vm.startPrank(AGENT);
        token.mint(INVESTOR, CAP);
        token.burn(INVESTOR, 400);
        assertEq(token.totalSupply(), CAP - 400);

        token.mint(INVESTOR2, 400);
        vm.stopPrank();
        assertEq(token.totalSupply(), CAP);
    }

    function testTransfersAreNeverGatedByTheCap() public {
        _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP);

        vm.prank(INVESTOR);
        token.transfer(INVESTOR2, 400);
        assertEq(token.balanceOf(INVESTOR2), 400);
    }

    function testRaisingTheCapRaisesTheCeiling() public {
        RuleMaxTotalSupplyERC3643 rule = _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP);

        vm.prank(ADMIN);
        rule.setMaxTotalSupply(CAP * 2);

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP);
        assertEq(token.totalSupply(), CAP * 2);
    }

    /*//////////////////////////////////////////////////////////////
              WHY THE STOCK RULE IS NOT USABLE HERE (NM-11)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The stock, CMTAT-shaped rule double-counts the mint on a real ERC-3643 token.
     * @dev `canTransfer` passes (0 + 1000 <= 1000), the token mints, then `created` finds
     *      `totalSupply() == 1000` and adds the amount again. A mint that exactly fills the cap
     *      reverts -- pre-flight and enforcement disagree inside one transaction.
     */
    function testStockRuleRevertsAMintThatExactlyFillsTheCap() public {
        _useStockRule();

        vm.prank(AGENT);
        vm.expectRevert();
        token.mint(INVESTOR, CAP);

        assertEq(token.totalSupply(), 0);
    }

    /**
     * @notice The stock rule halves the largest SINGLE mint it will accept.
     * @dev Only the amount in flight is double-counted, so a series of small mints can still creep to
     *      the full cap. That makes the damage look intermittent rather than a clean halving.
     */
    function testStockRuleHalvesTheLargestSingleMint() public {
        _useStockRule();

        vm.prank(AGENT);
        vm.expectRevert();
        token.mint(INVESTOR, CAP / 2 + 1);

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP / 2);
        assertEq(token.totalSupply(), CAP / 2);
    }

    /*//////////////////////////////////////////////////////////////
            COMPOSITION WITH THE PROOF-OF-RESERVE VARIANT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The documented pairing: PoR has no margin parameter, so a static ceiling is added by
     *         putting {RuleMaxTotalSupplyERC3643} in the same engine.
     * @dev Whichever limit binds first stops the mint. The engine returns the FIRST non-zero code, so
     *      rule order decides whether a rejection is reported as `50` or `75`.
     */
    function testComposesWithTheProofOfReserveVariant() public {
        // Reserves are generous; the static cap is the binding constraint.
        AggregatorV3Mock feed = new AggregatorV3Mock(0, int256(CAP * 10));
        RuleChainlinkPoRERC3643 por =
            new RuleChainlinkPoRERC3643(ADMIN, address(token), 0, AggregatorV3Interface(address(feed)), 0);
        RuleMaxTotalSupplyERC3643 cap = new RuleMaxTotalSupplyERC3643(ADMIN, address(token), CAP);

        vm.startPrank(ADMIN);
        engine.addRule(por);
        engine.addRule(cap);
        vm.stopPrank();

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP);

        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 1);
        assertEq(engine.detectTransferRestriction(address(0), INVESTOR, 1), CODE_MAX_TOTAL_SUPPLY_EXCEEDED);
    }

    /// @notice ...and with the reserves as the binding constraint instead, the PoR code is reported.
    function testTheTighterOfTheTwoLimitsBinds() public {
        AggregatorV3Mock feed = new AggregatorV3Mock(0, int256(CAP / 2));
        RuleChainlinkPoRERC3643 por =
            new RuleChainlinkPoRERC3643(ADMIN, address(token), 0, AggregatorV3Interface(address(feed)), 0);
        RuleMaxTotalSupplyERC3643 cap = new RuleMaxTotalSupplyERC3643(ADMIN, address(token), CAP);

        vm.startPrank(ADMIN);
        engine.addRule(por);
        engine.addRule(cap);
        vm.stopPrank();

        vm.prank(AGENT);
        token.mint(INVESTOR, CAP / 2);

        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 1);
        assertEq(token.totalSupply(), CAP / 2, "reserves bound before the static cap");
    }
}
