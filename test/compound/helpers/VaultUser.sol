// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@vaults/ERC4626UpgradeableSafe.sol";
import "@tests/compound/helpers/User.sol";

contract VaultUser is User {
    using SafeTransferLib for ERC20;

    constructor(Morpho _morpho) User(_morpho) {}

    function depositVault(ERC4626UpgradeableSafe tokenizedVault, uint256 _amount)
        external
        returns (uint256)
    {
        ERC20(tokenizedVault.asset()).safeApprove(address(tokenizedVault), _amount);
        return tokenizedVault.deposit(_amount, address(this));
    }

    function depositVault(
        ERC4626UpgradeableSafe tokenizedVault,
        uint256 _amount,
        address _to
    ) external returns (uint256) {
        ERC20(tokenizedVault.asset()).safeApprove(address(tokenizedVault), _amount);
        return tokenizedVault.deposit(_amount, _to);
    }

    function mintVault(ERC4626UpgradeableSafe tokenizedVault, uint256 _shares)
        external
        returns (uint256)
    {
        ERC20(tokenizedVault.asset()).safeApprove(
            address(tokenizedVault),
            tokenizedVault.previewMint(_shares)
        );
        return tokenizedVault.mint(_shares, address(this));
    }

    function mintVault(
        ERC4626UpgradeableSafe tokenizedVault,
        uint256 _shares,
        address _to
    ) external returns (uint256) {
        ERC20(tokenizedVault.asset()).safeApprove(
            address(tokenizedVault),
            tokenizedVault.previewMint(_shares)
        );
        return tokenizedVault.mint(_shares, _to);
    }

    function withdrawVault(
        ERC4626UpgradeableSafe tokenizedVault,
        uint256 _amount,
        address _owner
    ) public returns (uint256) {
        return tokenizedVault.withdraw(_amount, address(this), _owner);
    }

    function withdrawVault(
        ERC4626UpgradeableSafe tokenizedVault,
        uint256 _amount,
        address _receiver,
        address _owner
    ) public returns (uint256) {
        return tokenizedVault.withdraw(_amount, _receiver, _owner);
    }

    function withdrawVault(ERC4626UpgradeableSafe tokenizedVault, uint256 _amount)
        external
        returns (uint256)
    {
        return withdrawVault(tokenizedVault, _amount, address(this));
    }

    function redeemVault(
        ERC4626UpgradeableSafe tokenizedVault,
        uint256 _shares,
        address _receiver,
        address _owner
    ) public returns (uint256) {
        return tokenizedVault.redeem(_shares, _receiver, _owner);
    }

    function redeemVault(
        ERC4626UpgradeableSafe tokenizedVault,
        uint256 _shares,
        address _owner
    ) public returns (uint256) {
        return tokenizedVault.redeem(_shares, address(this), _owner);
    }

    function redeemVault(ERC4626UpgradeableSafe tokenizedVault, uint256 _shares)
        external
        returns (uint256)
    {
        return redeemVault(tokenizedVault, _shares, address(this));
    }
}
