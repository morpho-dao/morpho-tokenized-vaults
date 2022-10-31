// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.10;

import {IRewardsManager} from "@contracts/aave-v3/interfaces/IRewardsManager.sol";
import {IMorpho} from "@contracts/aave-v3/interfaces/IMorpho.sol";
import {ISupplyVault} from "./interfaces/ISupplyVault.sol";

import {ERC20, SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "@rari-capital/solmate/src/utils/SafeCastLib.sol";

import {SupplyVaultBase} from "./SupplyVaultBase.sol";

/// @title SupplyVault.
/// @author Morpho Labs.
/// @custom:contact security@morpho.xyz
/// @notice ERC4626-upgradeable Tokenized Vault implementation for Morpho-Aave V3, which tracks rewards from Aave's pool accrued by its users.
contract SupplyVault is ISupplyVault, SupplyVaultBase {
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;

    /// EVENTS ///

    /// @notice Emitted when rewards of an asset are accrued on behalf of a user.
    /// @param rewardToken The address of the reward token.
    /// @param user The address of the user that rewards are accrued on behalf of.
    /// @param rewardsIndex The index of the asset distribution on behalf of the user.
    /// @param accruedRewards The amount of rewards accrued.
    event Accrued(
        address indexed rewardToken,
        address indexed user,
        uint128 rewardsIndex,
        uint128 accruedRewards
    );

    /// @notice Emitted when rewards of an asset are claimed on behalf of a user.
    /// @param rewardToken The address of the reward token.
    /// @param user The address of the user that rewards are claimed on behalf of.
    /// @param claimedRewards The amount of rewards claimed.
    event Claimed(address indexed rewardToken, address indexed user, uint256 claimedRewards);

    /// STRUCTS ///

    struct UserRewardsData {
        uint128 index; // User rewards index for a given reward token (in wad).
        uint128 unclaimed; // Unclaimed amount for a given reward token (in reward tokens).
    }

    /// STORAGE ///

    uint256 public constant SCALE = 1e36;

    IRewardsManager public immutable rewardsManager; // Morpho's rewards manager.

    mapping(address => uint128) public rewardsIndex; // The current reward index for the given reward token.
    mapping(address => mapping(address => UserRewardsData)) public userRewards; // User rewards data. rewardToken -> user -> userRewards.

    /// CONSTRUCTOR ///

    /// @dev Initializes network-wide immutables.
    /// @param _morpho The address of the main Morpho contract.
    constructor(address _morpho) SupplyVaultBase(_morpho) {
        rewardsManager = morpho.rewardsManager();
    }

    /// INITIALIZER ///

    /// @dev Initializes the vault.
    /// @param _poolToken The address of the pool token corresponding to the market to supply through this vault.
    /// @param _name The name of the ERC20 token associated to this tokenized vault.
    /// @param _symbol The symbol of the ERC20 token associated to this tokenized vault.
    /// @param _initialDeposit The amount of the initial deposit used to prevent pricePerShare manipulation.
    function initialize(
        address _poolToken,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialDeposit
    ) external initializer {
        __SupplyVaultBase_init(_poolToken, _name, _symbol, _initialDeposit);
    }

    /// EXTERNAL ///

    /// @notice Claims rewards on behalf of `_user`.
    /// @param _user The address of the user to claim rewards for.
    /// @return rewardTokens The list of reward tokens.
    /// @return claimedAmounts The list of claimed amounts for each reward tokens.
    function claimRewards(address _user)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts)
    {
        _accrueUnclaimedRewards(_user);

        rewardTokens = morpho.rewardsController().getRewardsByAsset(poolToken);

        claimedAmounts = new uint256[](rewardTokens.length);

        for (uint256 i; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            UserRewardsData storage userRewardsData = userRewards[rewardToken][_user];

            uint128 unclaimedAmount = userRewardsData.unclaimed;
            if (unclaimedAmount > 0) {
                claimedAmounts[i] = unclaimedAmount;
                userRewardsData.unclaimed = 0;

                ERC20(rewardToken).safeTransfer(_user, unclaimedAmount);

                emit Claimed(rewardToken, _user, unclaimedAmount);
            }
        }
    }

    /// @notice Returns a given user's unclaimed rewards for all reward tokens.
    /// @param _user The address of the user.
    /// @return rewardTokens The list of reward tokens.
    /// @return unclaimedAmounts The list of unclaimed amounts for each reward token.
    function getAllUnclaimedRewards(address _user)
        external
        view
        returns (address[] memory rewardTokens, uint256[] memory unclaimedAmounts)
    {
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = poolToken;

        uint256[] memory claimableAmounts;
        (rewardTokens, claimableAmounts) = rewardsManager.getAllUserRewards(
            poolTokens,
            address(this)
        );

        unclaimedAmounts = new uint256[](claimableAmounts.length);
        uint256 supply = totalSupply();

        for (uint256 i; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            unclaimedAmounts[i] = _getUpdatedUnclaimedReward(
                _user,
                rewardToken,
                claimableAmounts[i],
                supply
            );
        }
    }

    /// @notice Returns user's rewards for the specificied reward token.
    /// @param _user The address of the user.
    /// @param _rewardToken The address of the reward token
    /// @return The user's rewards in reward token.
    function getUnclaimedRewards(address _user, address _rewardToken)
        external
        view
        returns (uint256)
    {
        address[] memory poolTokens = new address[](1);
        poolTokens[0] = poolToken;

        uint256 claimableRewards = rewardsManager.getUserRewards(
            poolTokens,
            address(this),
            _rewardToken
        );

        return _getUpdatedUnclaimedReward(_user, _rewardToken, claimableRewards, totalSupply());
    }

    /// INTERNAL ///

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal override {
        _accrueUnclaimedRewards(_receiver);
        super._deposit(_caller, _receiver, _assets, _shares);
    }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets,
        uint256 _shares
    ) internal override {
        _accrueUnclaimedRewards(_owner);
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    function _accrueUnclaimedRewards(address _user) internal {
        address[] memory rewardTokens;
        uint256[] memory claimedAmounts;

        {
            address[] memory poolTokens = new address[](1);
            poolTokens[0] = poolToken;

            (rewardTokens, claimedAmounts) = morpho.claimRewards(poolTokens, false);
        }

        uint256 supply = totalSupply();
        for (uint256 i; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            uint256 claimedAmount = claimedAmounts[i];
            uint128 rewardsIndexMem = rewardsIndex[rewardToken];

            if (supply > 0 && claimedAmount > 0) {
                rewardsIndexMem += _getUnaccruedRewardIndex(claimedAmount, supply);
                rewardsIndex[rewardToken] = rewardsIndexMem;
            }

            UserRewardsData storage userRewardsData = userRewards[rewardToken][_user];
            if (rewardsIndexMem > userRewardsData.index) {
                uint128 accruedReward = _getUnaccruedRewardsFromRewardsIndexAccrual(
                    balanceOf(_user),
                    rewardsIndexMem - userRewardsData.index
                );
                userRewardsData.unclaimed += accruedReward;
                userRewardsData.index = rewardsIndexMem;

                emit Accrued(rewardToken, _user, rewardsIndexMem, accruedReward);
            }
        }
    }

    function _getUpdatedUnclaimedReward(
        address _user,
        address _rewardToken,
        uint256 _claimableReward,
        uint256 _totalSupply
    ) internal view returns (uint128 unclaimed) {
        unclaimed =
            userRewards[_rewardToken][_user].unclaimed +
            _getUnaccruedRewardsFromRewardsIndexAccrual(
                balanceOf(_user),
                _getUnaccruedRewardIndex(_claimableReward, _totalSupply) + // The unaccrued reward index
                    rewardsIndex[_rewardToken] -
                    userRewards[_rewardToken][_user].index // The difference between the current reward index and the user's index
            );
    }

    function _getUnaccruedRewardsFromRewardsIndexAccrual(
        uint256 _userBalance,
        uint128 _indexAccrual
    ) internal pure returns (uint128 unaccruedReward) {
        unaccruedReward = _userBalance.mulDivDown(_indexAccrual, SCALE).safeCastTo128();
    }

    function _getUnaccruedRewardIndex(uint256 _claimableReward, uint256 _totalSupply)
        internal
        pure
        returns (uint128 unaccruedRewardIndex)
    {
        if (_totalSupply > 0)
            unaccruedRewardIndex = _claimableReward.mulDivDown(SCALE, _totalSupply).safeCastTo128();
    }
}
