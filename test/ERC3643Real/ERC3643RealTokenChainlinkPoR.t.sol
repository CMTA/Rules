// SPDX-License-Identifier: MPL-2.0
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ComplianceNotFollowed, Token} from "ERC3643/token/Token.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {
    RuleChainlinkPoRInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleChainlinkPoRInvariantStorage.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {RuleChainlinkPoRERC3643} from "src/rules/validation/deployment/RuleChainlinkPoRERC3643.sol";

/**
 * @title Proof of Reserve against the REAL vendored ERC-3643 token
 * @notice Deploys the genuine `Token` from `lib/ERC-3643/` (4.2.0-beta1) and drives it through:
 *
 *             real ERC-3643 Token ── compliance slot ──▶ RuleEngine ──▶ RuleChainlinkPoR[ERC3643]
 *                                 └─ identity slot ────▶ IdentityRegistryWhitelist
 *
 * @dev The point of this suite is the ORDER in which the real token consults compliance on a mint:
 *
 *      ```solidity
 *      function mint(address _to, uint256 _amount) public onlyAgent {
 *          require(_tokenCompliance.canTransfer(address(0), _to, _amount), ComplianceNotFollowed());
 *          _mint(_to, _amount);                        // <-- supply changes HERE
 *          _tokenCompliance.created(_to, _amount);     // <-- rule notified AFTERWARDS
 *      }
 *      ```
 *
 *      One transaction, both paths, different accounting. `canTransfer` runs BEFORE the mint, so it
 *      must project `_amount`; `created` runs AFTER, and `RuleEngine` forwards it as the three-argument
 *      `transferred(address(0), to, value)`, by which point `totalSupply()` already includes `_amount`.
 *      {RuleChainlinkPoRERC3643} re-phases only the second. The stock {RuleChainlinkPoR}, built for
 *      CMTAT (which calls the rule first), counts the amount twice and reverts a fully backed mint --
 *      `testStockRuleRevertsAFullyBackedMint` is that regression, run against the real token rather
 *      than a mock.
 *
 * @dev Built by the dedicated profile because `Token.sol` pins `pragma solidity 0.8.30` exactly:
 *
 *          FOUNDRY_PROFILE=erc3643 forge test
 */
contract ERC3643RealTokenChainlinkPoR is Test, RuleChainlinkPoRInvariantStorage {
    address private constant ADMIN = address(1);
    address private constant AGENT = address(10);
    address private constant INVESTOR = address(11);
    address private constant INVESTOR2 = address(12);

    /// @dev Feed and token both report 0 decimals, so a reserve answer is a token amount as-is.
    uint256 private constant RESERVES = 1000;
    uint8 private constant TRANSFER_OK_CODE = 0;

    IdentityRegistryWhitelist private registry;
    AggregatorV3Mock private feed;
    RuleEngine private engine;
    Token private token;

    function setUp() public {
        token = new Token();
        feed = new AggregatorV3Mock(0, int256(RESERVES));

        vm.startPrank(ADMIN);
        registry = new IdentityRegistryWhitelist(ADMIN);
        engine = new RuleEngine(ADMIN, address(0), address(0));
        vm.stopPrank();

        _wire();
    }

    /// @dev Everything except which rule sits in the engine; the rule is added per test.
    function _wire() private {
        vm.prank(ADMIN);
        engine.setTokenSelfBindingApproval(address(token), true);

        token.init(address(registry), address(engine), "Real ERC-3643 PoR", "R3643", 0, address(0));

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

    function _useErc3643Rule() private returns (RuleChainlinkPoRERC3643 rule) {
        rule = new RuleChainlinkPoRERC3643(ADMIN, address(token), 0, AggregatorV3Interface(address(feed)), 0);
        vm.prank(ADMIN);
        engine.addRule(rule);
    }

    function _useStockRule() private returns (RuleChainlinkPoR rule) {
        rule = new RuleChainlinkPoR(ADMIN, address(token), 0, AggregatorV3Interface(address(feed)), 0);
        vm.prank(ADMIN);
        engine.addRule(rule);
    }

    /*//////////////////////////////////////////////////////////////
                        THE ERC-3643 VARIANT
    //////////////////////////////////////////////////////////////*/

    function testMintUpToTheReservesSucceeds() public {
        _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES);

        assertEq(token.totalSupply(), RESERVES, "a mint of exactly the backed supply must land");
        assertEq(token.balanceOf(INVESTOR), RESERVES);
    }

    function testMintBeyondTheReservesIsRejected() public {
        _useErc3643Rule();

        // Blocked by the pre-flight `canTransfer` the token runs before `_mint`.
        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, RESERVES + 1);

        assertEq(token.totalSupply(), 0, "nothing may be issued past the reserves");
    }

    function testIncrementalMintsShareTheSameReserveCeiling() public {
        _useErc3643Rule();

        vm.startPrank(AGENT);
        token.mint(INVESTOR, 600);
        token.mint(INVESTOR2, 400);
        vm.stopPrank();
        assertEq(token.totalSupply(), RESERVES);

        // The reserves are now fully committed; one more unit is not backed.
        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 1);
    }

    function testRaisingTheReservesRaisesTheCeiling() public {
        _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES);

        feed.setAnswer(int256(RESERVES * 2));

        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES);
        assertEq(token.totalSupply(), RESERVES * 2);
    }

    function testTransfersAndBurnsAreNeverGatedByTheFeed() public {
        _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES);

        // Reserves collapse to nothing: issuance stops, holders stay mobile.
        feed.setAnswer(0);

        vm.prank(INVESTOR);
        token.transfer(INVESTOR2, 400);
        assertEq(token.balanceOf(INVESTOR2), 400);

        vm.prank(AGENT);
        token.burn(INVESTOR2, 400);
        assertEq(token.totalSupply(), RESERVES - 400);

        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 1);
    }

    function testAStaleFeedStopsIssuanceButNotHolders() public {
        RuleChainlinkPoRERC3643 rule = _useErc3643Rule();

        vm.prank(ADMIN);
        rule.setMaxStalenessSeconds(1 hours);

        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(AGENT);
        vm.expectRevert(ComplianceNotFollowed.selector);
        token.mint(INVESTOR, 1);

        // ...but the existing holder can still move and exit.
        vm.prank(INVESTOR);
        token.transfer(INVESTOR2, 100);
        assertEq(token.balanceOf(INVESTOR2), 100);
    }

    /*//////////////////////////////////////////////////////////////
              WHY THE STOCK RULE IS NOT USABLE HERE (NM-11)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The stock, CMTAT-shaped rule double-counts the mint on a real ERC-3643 token.
     * @dev `canTransfer` passes (supply 0 + 1000 <= 1000), the token mints, and then `created` finds
     *      `totalSupply() == 1000` and adds the amount a second time. The mint reverts even though it
     *      is exactly and fully backed -- the pre-flight answer and enforcement disagree inside one
     *      transaction.
     */
    function testStockRuleRevertsAFullyBackedMint() public {
        _useStockRule();

        vm.prank(AGENT);
        vm.expectRevert();
        token.mint(INVESTOR, RESERVES);

        assertEq(token.totalSupply(), 0, "the fully backed mint was rejected");
    }

    /**
     * @notice The stock rule halves the largest SINGLE mint it will accept.
     * @dev Every mint has its amount counted twice -- once by the post-mint `totalSupply()` and once
     *      as `value` -- so from an empty supply the ceiling on one mint is `RESERVES / 2`. Note the
     *      damage is not a uniform halving of the cap: a series of small mints can still creep up to
     *      the full reserves, since only the amount in flight is double-counted. What is guaranteed
     *      is that some fully backed mints are refused, and which ones depends on how issuance is
     *      chunked -- a worse failure mode than a plainly halved cap, because it looks intermittent.
     */
    function testStockRuleHalvesTheLargestSingleMint() public {
        _useStockRule();

        // One over half the reserves: post-mint supply 501 plus 501 again exceeds 1000.
        vm.prank(AGENT);
        vm.expectRevert();
        token.mint(INVESTOR, RESERVES / 2 + 1);

        // Exactly half is the most it will take in one go.
        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES / 2);
        assertEq(token.totalSupply(), RESERVES / 2);
    }

    /*//////////////////////////////////////////////////////////////
                    THE READ PATH IS NOT RE-PHASED
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The ERC-3643 variant still projects the pending amount on the read path.
     * @dev The token itself depends on this: it calls `canTransfer(address(0), to, amount)` BEFORE
     *      `_mint`, so a view that ignored `amount` would wave through a mint the write hook then
     *      reverts. Only the notification is re-phased.
     */
    function testPreFlightViewStillProjectsThePendingAmount() public {
        RuleChainlinkPoRERC3643 rule = _useErc3643Rule();

        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES);

        assertEq(
            rule.detectTransferRestriction(address(0), INVESTOR, 1),
            CODE_RESERVES_EXCEEDED,
            "pre-flight must still count the amount being requested"
        );
        assertFalse(rule.canTransfer(address(0), INVESTOR, 1));

        // And it agrees with the token's own pre-flight consultation.
        assertFalse(engine.canTransfer(address(0), INVESTOR, 1));
    }

    /*//////////////////////////////////////////////////////////////
                    THE SUPPLY READ ITSELF
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Code 78 (`CODE_TOTAL_SUPPLY_UNAVAILABLE`) is unreachable against a directly deployed
     *         ERC-3643 token, so the guarded read costs nothing but is not dead weight either.
     * @dev `Token.totalSupply()` is `external view { return _totalSupply; }` — no modifier, no
     *      external call, so it cannot revert and `_currentSupply()` always reports available. The
     *      branch still earns its place: the standard T-REX deployment puts the token behind a
     *      `TokenProxy` whose implementation is resolved through an `ImplementationAuthority`, and a
     *      proxy repointed at a bad implementation *can* make `totalSupply()` revert. The rule then
     *      returns 78 and blocks minting rather than breaking the MUST-NOT-revert views.
     */
    function testSupplyIsAlwaysReadableOnADirectlyDeployedToken() public {
        RuleChainlinkPoRERC3643 rule = _useErc3643Rule();

        assertEq(rule.detectTransferRestriction(address(0), INVESTOR, 1), TRANSFER_OK_CODE);

        vm.prank(AGENT);
        token.mint(INVESTOR, RESERVES);

        // Still readable with a non-zero supply; the ceiling, not the read, is what now binds.
        assertEq(rule.detectTransferRestriction(address(0), INVESTOR, 1), CODE_RESERVES_EXCEEDED);
    }

    /**
     * @notice DEPLOYMENT ORDER: build the rule AFTER `Token.init`, or its cached decimals are wrong.
     * @dev ERC-3643 deploys then initialises, and an uninitialised `Token` reports `decimals() == 0`.
     *      The rule's constructor probes `decimals()` and accepts a matching `0`, so a rule built
     *      first is happily configured for a 0-decimals token — and then `init(..., 18, ...)` makes it
     *      an 18-decimals token while the rule still believes 0. Nothing reverts and no event marks
     *      it; the reserve answer is simply scaled by `10 ** 18` too little, and every mint is
     *      refused. The same mistake with the decimals reversed would over-mint instead.
     *
     *      There is no on-chain fix: the constructor probe genuinely succeeded. The remedy is
     *      ordering (construct after `init`) or calling `setTokenMetadata` afterwards to re-sync.
     */
    function testRuleBuiltBeforeInitCachesTheWrongDecimals() public {
        Token fresh = new Token();
        assertEq(fresh.decimals(), 0, "an uninitialised token reports 0 decimals");

        AggregatorV3Mock scaledFeed = new AggregatorV3Mock(8, int256(RESERVES * 1e8));
        RuleChainlinkPoRERC3643 early =
            new RuleChainlinkPoRERC3643(ADMIN, address(fresh), 0, AggregatorV3Interface(address(scaledFeed)), 0);

        RuleEngine freshEngine = new RuleEngine(ADMIN, address(0), address(0));
        vm.prank(ADMIN);
        freshEngine.setTokenSelfBindingApproval(address(fresh), true);
        fresh.init(address(registry), address(freshEngine), "Late init", "LATE", 18, address(0));

        assertEq(fresh.decimals(), 18, "the token is now an 18-decimals token");
        assertEq(early.tokenDecimals(), 0, "but the rule still believes 0");

        (, uint256 backed) = early.maxBackedSupply();
        assertEq(backed, RESERVES, "reserves scaled into 0 decimals");

        // Re-syncing after init is the operator-side remedy.
        vm.prank(ADMIN);
        early.setTokenMetadata(address(fresh), 18);
        (, uint256 corrected) = early.maxBackedSupply();
        assertEq(corrected, RESERVES * 1e18, "and now the ceiling is in the token's own units");
    }

    /// @notice The variant reports the same reserve ceiling as the stock rule; only enforcement differs.
    function testMaxBackedSupplyIsUnchanged() public {
        RuleChainlinkPoRERC3643 rule = _useErc3643Rule();

        (uint8 code, uint256 backed) = rule.maxBackedSupply();
        assertEq(code, 0);
        assertEq(backed, RESERVES);
    }
}
