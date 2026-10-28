// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IERC734KeyHasPurpose, IIdentityRegistryERC3643} from "../registry/interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title IERC3643ComplianceForToken — the compliance surface `Token.sol` calls.
 * @dev Declared here rather than reused from `IERC3643ComplianceFull`, which exists solely to
 * compute an ERC-165 interface ID and is explicitly not meant to be used as a type.
 */
interface IERC3643ComplianceForToken {
    /**
     * @notice Binds a token to this compliance contract.
     * @param token The token being bound.
     */
    function bindToken(address token) external;

    /**
     * @notice Unbinds a previously bound token.
     * @param token The token being unbound.
     */
    function unbindToken(address token) external;

    /**
     * @notice Notifies the compliance contract that a transfer has occurred.
     * @param from The sender.
     * @param to The recipient.
     * @param value The amount moved.
     */
    function transferred(address from, address to, uint256 value) external;

    /**
     * @notice Notifies the compliance contract that tokens have been minted.
     * @param to The recipient.
     * @param value The amount minted.
     */
    function created(address to, uint256 value) external;

    /**
     * @notice Notifies the compliance contract that tokens have been burned.
     * @param from The holder burned from.
     * @param value The amount burned.
     */
    function destroyed(address from, uint256 value) external;

    /**
     * @notice Returns whether a transfer is allowed.
     * @param from The sender, or the zero address for a mint.
     * @param to The recipient.
     * @param value The amount to move.
     * @return True when the transfer is allowed.
     */
    function canTransfer(address from, address to, uint256 value) external view returns (bool);
}

/**
 * @title ERC3643TokenMock -- a minimal ERC-3643 token reproducing the identity-registry call
 * sequences of the reference implementation.
 * @notice The registry-facing logic of `transfer`, `transferFrom`, `forcedTransfer`, `mint`, `burn`
 * and `recoveryAddress` is transcribed from ERC-3643's vendored `Token.sol`, call order and revert
 * strings included, so a registry that satisfies this mock satisfies the real token.
 *
 * @dev The real `Token.sol` does not compile here: it imports the un-vendored ONCHAINID package and
 * targets OZ v4 upgradeable, while this repo vendors OZ v5. The mock keeps the registry interaction
 * faithful and drops the compliance module, pausing and partial-freeze accounting.
 *
 * WARNING: test scaffolding only. Not a compliant ERC-3643 token, not for production.
 *
 * NOTE: the linter suppressions are deliberate -- keeping the reference parameter names and the
 * plain `keccak256(abi.encode(...))` key derivation is the point. {IdentityRegistryWhitelistBase}
 * derives the same key in assembly, and the tests only prove the two agree because this side
 * computes it the ordinary way. Rewriting it would make the cross-check circular.
 */
contract ERC3643TokenMock {
    /**
     * @notice The identity registry this token consults on every inbound transfer.
     */
    IIdentityRegistryERC3643 public identityRegistry;
    /**
     * @notice The compliance contract, i.e. a `RuleEngine`.
     * @dev Optional here, unlike the real token which requires one: when unset the compliance calls
     * are skipped, so identity-registry tests can run without wiring an engine. Every call that IS
     * made follows `Token.sol` exactly.
     */
    IERC3643ComplianceForToken public compliance;

    /**
     * @notice Token balance per account.
     */
    mapping(address account => uint256 balance) public balanceOf;
    /**
     * @notice Whether an account holds the ERC-3643 agent role.
     */
    mapping(address account => bool isAgent) public isAgent;
    /**
     * @notice Total token supply.
     */
    uint256 public totalSupply;

    /**
     * @notice Emitted on every balance movement, including mint and burn.
     * @param from The sender, or the zero address for a mint.
     * @param to The recipient, or the zero address for a burn.
     * @param value The amount moved.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    /**
     * @notice Emitted when a position is recovered onto a replacement wallet.
     * @param lostWallet The wallet recovered from.
     * @param newWallet The replacement wallet.
     * @param investorOnchainId The identity contract that vouched for the replacement wallet.
     */
    event RecoverySuccess(address indexed lostWallet, address indexed newWallet, address indexed investorOnchainId);

    error ERC3643TokenMock_OnlyAgent();

    /**
     * @param identityRegistry_ The registry this token consults.
     * @param agent The address granted the agent role.
     */
    constructor(IIdentityRegistryERC3643 identityRegistry_, address agent) {
        identityRegistry = identityRegistry_;
        isAgent[agent] = true;
    }

    // forge-lint: disable-next-line(unwrapped-modifier-logic)
    modifier onlyAgent() {
        require(isAgent[msg.sender], ERC3643TokenMock_OnlyAgent());
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the identity registry, mirroring `Token.setIdentityRegistry`.
     * @param identityRegistry_ The new registry.
     */
    function setIdentityRegistry(IIdentityRegistryERC3643 identityRegistry_) external {
        identityRegistry = identityRegistry_;
    }

    /**
     * @notice Sets the compliance contract, mirroring `Token.setCompliance`.
     * @dev Transcribed from `Token.sol:515-522`: unbinds the previous compliance, then makes the
     *      **token itself** call `bindToken(address(this))` on the new one. That self-call is why a
     *      `RuleEngine` needs `setTokenSelfBindingApproval(token, true)` first.
     * @param compliance_ The new compliance contract.
     */
    function setCompliance(IERC3643ComplianceForToken compliance_) external {
        if (address(compliance) != address(0)) {
            compliance.unbindToken(address(this));
        }
        compliance = compliance_;
        compliance.bindToken(address(this));
    }

    /**
     * @notice Grants or revokes the agent role.
     * @param account The account to update.
     * @param status True to grant.
     */
    function setAgent(address account, bool status) external {
        isAgent[account] = status;
    }

    /**
     * @notice Transfers tokens; the recipient must be verified.
     * @dev `Token.transfer`: `if (isVerified(_to) && compliance.canTransfer(...))`. The compliance
     * leg is omitted here; the registry leg is identical.
     * @param _to Recipient.
     * @param _amount Amount to transfer.
     * @return True on success.
     */
    function transfer(address _to, uint256 _amount) external returns (bool) {
        require(_amount <= balanceOf[msg.sender], "Insufficient Balance");
        if (identityRegistry.isVerified(_to) && _canTransfer(msg.sender, _to, _amount)) {
            _transfer(msg.sender, _to, _amount);
            _complianceTransferred(msg.sender, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     * @notice Transfers tokens on behalf of `_from`; the recipient must be verified.
     * @dev `Token.transferFrom`. Allowance handling is omitted; the registry leg is identical.
     * @param _from Sender.
     * @param _to Recipient.
     * @param _amount Amount to transfer.
     * @return True on success.
     */
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        require(_amount <= balanceOf[_from], "Insufficient Balance");
        if (identityRegistry.isVerified(_to) && _canTransfer(_from, _to, _amount)) {
            _transfer(_from, _to, _amount);
            _complianceTransferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     * @notice Mints tokens; the recipient must be verified.
     * @dev `Token.mint`: `require(isVerified(_to), "Identity is not verified.")`.
     * @param _to Recipient.
     * @param _amount Amount to mint.
     */
    function mint(address _to, uint256 _amount) external onlyAgent {
        require(identityRegistry.isVerified(_to), "Identity is not verified.");
        require(_canTransfer(address(0), _to, _amount), "Compliance not followed");
        balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _to, _amount);
        if (address(compliance) != address(0)) {
            compliance.created(_to, _amount);
        }
    }

    /**
     * @notice Burns tokens.
     * @dev `Token.burn` makes **no** registry call: a de-listed holder can still be burned out.
     * @param _userAddress Holder to burn from.
     * @param _amount Amount to burn.
     */
    function burn(address _userAddress, uint256 _amount) external onlyAgent {
        require(balanceOf[_userAddress] >= _amount, "cannot burn more than balance");
        balanceOf[_userAddress] -= _amount;
        totalSupply -= _amount;
        emit Transfer(_userAddress, address(0), _amount);
        if (address(compliance) != address(0)) {
            compliance.destroyed(_userAddress, _amount);
        }
    }

    /**
     * @notice Moves an investor's position to a replacement wallet.
     * @dev Transcribed from `Token.recoveryAddress`, preserving the order that matters:
     *      1. `keyHasPurpose(keccak256(abi.encode(_newWallet)), 1)` on the **caller-supplied**
     *         `_investorOnchainId` -- reverts "Recovery not possible" when false;
     *      2. `investorCountry(_lostWallet)` read from the registry;
     *      3. `registerIdentity(_newWallet, _investorOnchainId, country)` -- called BY THE TOKEN;
     *      4. `forcedTransfer(_lostWallet, _newWallet, balance)`;
     *      5. `deleteIdentity(_lostWallet)` -- also called BY THE TOKEN.
     * @param _lostWallet The wallet to recover from.
     * @param _newWallet The replacement wallet.
     * @param _investorOnchainId The contract answering `keyHasPurpose`.
     * @return True on success.
     */
    function recoveryAddress(address _lostWallet, address _newWallet, address _investorOnchainId)
        external
        onlyAgent
        returns (bool)
    {
        require(balanceOf[_lostWallet] != 0, "no tokens to recover");
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 _key = keccak256(abi.encode(_newWallet));
        if (IERC734KeyHasPurpose(_investorOnchainId).keyHasPurpose(_key, 1)) {
            uint256 investorTokens = balanceOf[_lostWallet];
            identityRegistry.registerIdentity(
                _newWallet, _investorOnchainId, identityRegistry.investorCountry(_lostWallet)
            );
            forcedTransfer(_lostWallet, _newWallet, investorTokens);
            identityRegistry.deleteIdentity(_lostWallet);
            emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainId);
            return true;
        }
        revert("Recovery not possible");
    }

    /**
     * @notice Agent-forced transfer; the recipient must still be verified.
     * @dev `Token.forcedTransfer`: bypasses freezes but NOT the registry check on `_to`.
     * @param _from Sender.
     * @param _to Recipient.
     * @param _amount Amount to transfer.
     * @return True on success.
     */
    function forcedTransfer(address _from, address _to, uint256 _amount) public onlyAgent returns (bool) {
        require(balanceOf[_from] >= _amount, "sender balance too low");
        // NOTE: `Token.forcedTransfer` does NOT consult `canTransfer` -- it only notifies
        // `transferred` afterwards. A compliance contract that reverts in `transferred` (as a
        // RuleEngine does) still blocks the move; one that only answers `canTransfer` does not.
        if (identityRegistry.isVerified(_to)) {
            _transfer(_from, _to, _amount);
            _complianceTransferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Notifies the compliance contract that a transfer happened; no-op when none is set.
     * @param from Sender.
     * @param to Recipient.
     * @param amount Amount moved.
     */
    function _complianceTransferred(address from, address to, uint256 amount) internal {
        if (address(compliance) != address(0)) {
            compliance.transferred(from, to, amount);
        }
    }

    /**
     * @notice Moves value between two balances.
     * @param from Sender.
     * @param to Recipient.
     * @param amount Amount to move.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    /**
     * @notice Asks the compliance contract whether a move is allowed; true when none is set.
     * @param from Sender, or the zero address for a mint.
     * @param to Recipient.
     * @param amount Amount to move.
     * @return True when the move is allowed.
     */
    function _canTransfer(address from, address to, uint256 amount) internal view returns (bool) {
        if (address(compliance) == address(0)) {
            return true;
        }
        return compliance.canTransfer(from, to, amount);
    }
}
