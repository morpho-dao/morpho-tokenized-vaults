// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.13;

import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "@rari-capital/solmate/src/utils/SafeCastLib.sol";

import {SupplyVaultBase, SafeTransferLib, ERC20} from "./SupplyVaultBase.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Compound, which tracks rewards from Compound's pool accrued by its users.
contract SupplyVault is SupplyVaultBase {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /// EVENTS ///

    /// @notice Emitted when a user accrues its rewards.
    /// @param user The address of the user.
    /// @param index The new index of the user (also the global at the moment of the update).
    /// @param unclaimed The new unclaimed amount of the user.
    event Accrued(address indexed user, uint256 index, uint256 unclaimed);

    /// @notice Emitted when a user claims its rewards.
    /// @param user The address of the user.
    /// @param claimed The amount of rewards claimed.
    event Claimed(address indexed user, uint256 claimed);

    /// STORAGE ///

    struct UserRewards {
        uint128 index; // User index for the reward token.
        uint128 unclaimed; // User's unclaimed rewards.
    }

    uint256 public rewardsIndex; // The vault's rewards index.
    mapping(address => UserRewards) public userRewards; // The rewards index of a user, used to track rewards accrued.

    /// UPGRADE ///

    /// @notice Initializes the vault.
    /// @param _morpho The address of the main Morpho contract.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function initialize(
        address _morpho,
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) external initializer {
        __SupplyVaultBase_init(_morpho, _poolToken, _name, _symbol, _initialDeposit);
    }

    /// EXTERNAL ///

    /// @notice Claims rewards on behalf of `_user`.
    /// @param _user The address of the user to claim rewards for.
    /// @return rewardsAmount The amount of rewards claimed.
    function claimRewards(address _user) external returns (uint256 rewardsAmount) {
        _accrueUnclaimedRewards(_user);

        rewardsAmount = userRewards[_user].unclaimed;
        if (rewardsAmount > 0) {
            userRewards[_user].unclaimed = 0;

            comp.safeTransfer(_user, rewardsAmount);
        }

        emit Claimed(_user, rewardsAmount);
    }

    /// INTERNAL ///

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        _accrueUnclaimedRewards(_receiver);
        super._deposit(_caller, _receiver, _assets, _shares);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal virtual override {
        _accrueUnclaimedRewards(_receiver);
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    function _accrueUnclaimedRewards(address _user) internal {
        uint256 supply = totalSupply();
        uint256 rewardsIndexMem = rewardsIndex;

        if (supply > 0) {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = poolToken;
            rewardsIndexMem += morpho.claimRewards(poolTokens, false).divWadDown(supply);
        }

        rewardsIndex = rewardsIndexMem;
        uint256 rewardsIndexDiff = rewardsIndexMem - userRewards[_user].index;
        uint256 unclaimed;

        if (rewardsIndexDiff > 0) {
            unclaimed =
                userRewards[_user].unclaimed +
                balanceOf(_user).mulWadDown(rewardsIndexDiff).safeCastTo128();
            userRewards[_user].unclaimed = unclaimed.safeCastTo128();
        }

        userRewards[_user].index = rewardsIndexMem.safeCastTo128();

        emit Accrued(_user, rewardsIndexMem, unclaimed);
    }
}
