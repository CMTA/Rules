// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {RuleBlacklist} from "../../rules/validation/deployment/RuleBlacklist.sol";
import {RuleConditionalTransferLight} from "../../rules/operation/RuleConditionalTransferLight.sol";
import {RuleERC2980} from "../../rules/validation/deployment/RuleERC2980.sol";
import {RuleIdentityRegistry} from "../../rules/validation/deployment/RuleIdentityRegistry.sol";
import {RuleMaxTotalSupply} from "../../rules/validation/deployment/RuleMaxTotalSupply.sol";

/**
 * @title VirtualHookOverrideHarnesses
 * @notice Proves that the `virtual` convention actually holds for functions that were previously
 *         non-`virtual` and therefore impossible to override (`CLAUDE_ANALYSIS.md` E-1, E-2, E-3).
 * @dev These contracts exist to be compiled: dropping `virtual` from any function they override
 *      makes the whole project fail to build, which is the only way a convention with no runtime
 *      behaviour can be regression-tested. The accompanying tests additionally check that the
 *      override is reached, so this is not merely a compile-time assertion.
 *
 *      For E-3 the coverage is deliberately REPRESENTATIVE, not exhaustive: one function is
 *      overridden per family (address-set write, ERC-2980 list write, rule configuration setter,
 *      approval write, token-facing `transferred` hook, binding). Overriding all 27 would add bulk
 *      without adding signal, because the compiler applies `virtual` per function, not per family --
 *      so a regression on an uncovered sibling would still slip through. That residual gap is the
 *      known cost of the sampling.
 */

/**
 * @notice Overrides the transfer-execution authorization hook with an allow-list of one address.
 * @dev Before the hook was made `virtual`, a subclass could not change who may consume approvals --
 *      the most likely customization point on this rule.
 */
contract ConditionalTransferLightCustomExecutorHarness is RuleConditionalTransferLight {
    /**
     * @notice The only address permitted to execute approved transfers.
     */
    address public immutable SOLE_EXECUTOR;

    /**
     * @notice Raised when a caller other than {SOLE_EXECUTOR} tries to execute a transfer.
     */
    error NotTheSoleExecutor(address caller);

    constructor(address admin, address soleExecutor) RuleConditionalTransferLight(admin) {
        SOLE_EXECUTOR = soleExecutor;
    }

    /**
     * @notice Counts calls that reached the overridden public entrypoints (`CLAUDE_ANALYSIS.md` E-3).
     */
    uint256 public approveTransferOverrideCalls;
    /**
     * @notice Counts calls that reached the overridden `transferred` hook (`CLAUDE_ANALYSIS.md` E-3).
     */
    uint256 public transferredOverrideCalls;

    /**
     * @notice Replaces the bound-token / bound-engine policy with a single hard-coded executor.
     */
    function _authorizeTransferExecution() internal view virtual override {
        require(_msgSender() == SOLE_EXECUTOR, NotTheSoleExecutor(_msgSender()));
    }

    /**
     * @notice Records that the override ran, then defers to the base approval logic.
     */
    function approveTransfer(address from, address to, uint256 value) public virtual override {
        ++approveTransferOverrideCalls;
        super.approveTransfer(from, to, value);
    }

    /**
     * @notice Records that the override ran, then defers to the base compliance hook.
     * @dev The token-facing `transferred` entrypoints were among the least overridable functions in
     *      the library before E-3.
     */
    function transferred(address from, address to, uint256 value) public virtual override {
        ++transferredOverrideCalls;
        super.transferred(from, to, value);
    }
}

/**
 * @notice Overrides a rule-configuration setter (`CLAUDE_ANALYSIS.md` E-3).
 * @dev `setMaxTotalSupply` was non-`virtual` while the equivalent setters on the sibling
 *      `RuleChainlinkPoR` were `virtual` -- the inconsistency E-3 calls out.
 */
contract MaxTotalSupplyCappedSetterHarness is RuleMaxTotalSupply {
    /**
     * @notice Hard ceiling this subclass refuses to raise the cap above.
     */
    uint256 public constant HARD_CEILING = 1_000_000;

    /**
     * @notice Raised when a caller tries to set a cap above {HARD_CEILING}.
     */
    error AboveHardCeiling(uint256 requested);

    constructor(address admin, address tokenContract_, uint256 maxTotalSupply_)
        RuleMaxTotalSupply(admin, tokenContract_, maxTotalSupply_)
    {}

    /**
     * @notice Adds a ceiling the base setter does not have.
     */
    function setMaxTotalSupply(uint256 newMaxTotalSupply) public virtual override {
        require(newMaxTotalSupply <= HARD_CEILING, AboveHardCeiling(newMaxTotalSupply));
        super.setMaxTotalSupply(newMaxTotalSupply);
    }
}

/**
 * @notice Overrides an identity-registry configuration setter (`CLAUDE_ANALYSIS.md` E-3).
 */
contract IdentityRegistryPinnedHarness is RuleIdentityRegistry {
    /**
     * @notice Raised when any attempt is made to repoint the registry.
     */
    error RegistryIsPinned();

    constructor(address admin, address identityRegistry_, bool checkSender_, bool checkSpender_)
        RuleIdentityRegistry(admin, identityRegistry_, checkSender_, checkSpender_)
    {}

    /**
     * @notice Makes the configured registry immutable after deployment.
     */
    function setIdentityRegistry(address) public virtual override {
        revert RegistryIsPinned();
    }
}

/**
 * @notice Overrides an ERC-2980 list write (`CLAUDE_ANALYSIS.md` E-3).
 * @dev Representative of the eight near-identical list functions on `RuleERC2980Base`.
 */
contract ERC2980SelfWhitelistBlockHarness is RuleERC2980 {
    /**
     * @notice Raised when the rule itself is whitelisted.
     */
    error CannotWhitelistTheRule();

    constructor(address admin, address forwarderIrrevocable, bool allowMintBurn)
        RuleERC2980(admin, forwarderIrrevocable, allowMintBurn)
    {}

    /**
     * @notice Rejects whitelisting this contract, then defers to the base implementation.
     */
    function addWhitelistAddress(address targetAddress) public virtual override {
        require(targetAddress != address(this), CannotWhitelistTheRule());
        super.addWhitelistAddress(targetAddress);
    }
}

/**
 * @notice Overrides the blacklist's restriction hook to also reject a single quarantined address.
 * @dev Exercises `_detectTransferRestriction` and `_detectTransferRestrictionFrom`, both of which
 *      were non-`virtual` on this rule.
 */
contract BlacklistQuarantineHarness is RuleBlacklist {
    /**
     * @notice Restriction code returned for the quarantined address.
     */
    uint8 public constant CODE_QUARANTINED = 200;

    /**
     * @notice Address rejected in addition to whatever the blacklist itself decides.
     */
    address public immutable QUARANTINED;

    /**
     * @notice Raised when the quarantined address is passed to the overridden {addAddress}.
     */
    error CannotListQuarantined();

    constructor(address admin, address forwarderIrrevocable, address quarantined)
        RuleBlacklist(admin, forwarderIrrevocable)
    {
        QUARANTINED = quarantined;
    }

    /**
     * @notice Applies the base blacklist check, then the extra quarantine rule.
     */
    function _detectTransferRestriction(address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        uint8 code = super._detectTransferRestriction(from, to, value);
        if (code != uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)) {
            return code;
        }
        if (from == QUARANTINED || to == QUARANTINED) {
            return CODE_QUARANTINED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Applies the base spender check, then the extra quarantine rule to the spender.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        uint8 code = super._detectTransferRestrictionFrom(spender, from, to, value);
        if (code != uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)) {
            return code;
        }
        if (spender == QUARANTINED) {
            return CODE_QUARANTINED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Hard-denies the fungible `canTransfer` view (`CLAUDE_ANALYSIS.md` E-2).
     * @dev Deliberately contradicts {detectTransferRestriction} so the test can prove the override is
     *      what answers, rather than the inherited implementation.
     */
    function canTransfer(address from, address to, uint256 amount) public view virtual override returns (bool isValid) {
        from;
        to;
        amount;
        return false;
    }

    /**
     * @notice Hard-denies the ERC-7943 `canTransfer` overload (`CLAUDE_ANALYSIS.md` E-2).
     */
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount)
        public
        view
        virtual
        override
        returns (bool)
    {
        from;
        to;
        tokenId;
        amount;
        return false;
    }

    /**
     * @notice Rejects listing the quarantined address, then defers to the base set write.
     * @dev Representative of the four `RuleAddressSet` write functions (`CLAUDE_ANALYSIS.md` E-3).
     */
    function addAddress(address targetAddress) public virtual override {
        require(targetAddress != QUARANTINED, CannotListQuarantined());
        super.addAddress(targetAddress);
    }
}
