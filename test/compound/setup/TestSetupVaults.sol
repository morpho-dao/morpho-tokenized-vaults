// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "@tests/compound/setup/TestSetup.sol";

import {SupplyHarvestVault} from "@vaults/compound/SupplyHarvestVault.sol";
import {SupplyVault} from "@vaults/compound/SupplyVault.sol";

import "@morpho-labs/morpho-utils/math/PercentageMath.sol";

import "../helpers/VaultUser.sol";

contract TestSetupVaults is TestSetup {
    using SafeTransferLib for ERC20;

    TransparentUpgradeableProxy internal wethSupplyVaultProxy;
    TransparentUpgradeableProxy internal wethSupplyHarvestVaultProxy;

    SupplyVault internal supplyVaultImplV1;
    SupplyHarvestVault internal supplyHarvestVaultImplV1;

    SupplyVault internal wethSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;
    SupplyHarvestVault internal wethSupplyHarvestVault;
    SupplyHarvestVault internal daiSupplyHarvestVault;
    SupplyHarvestVault internal usdcSupplyHarvestVault;
    SupplyHarvestVault internal compSupplyHarvestVault;

    ERC20 mcWeth;
    ERC20 mcDai;
    ERC20 mcUsdc;
    ERC20 mchWeth;
    ERC20 mchDai;
    ERC20 mchUsdc;
    ERC20 mchComp;

    VaultUser public vaultSupplier1;
    VaultUser public vaultSupplier2;
    VaultUser public vaultSupplier3;
    VaultUser[] public vaultSuppliers;

    function onSetUp() public override {
        initVaultContracts();
        setVaultContractsLabels();
        initVaultUsers();
    }

    function initVaultContracts() internal {
        supplyVaultImplV1 = new SupplyVault();
        supplyHarvestVaultImplV1 = new SupplyHarvestVault();

        wethSupplyHarvestVaultProxy = new TransparentUpgradeableProxy(
            address(supplyHarvestVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyHarvestVault = SupplyHarvestVault(address(wethSupplyHarvestVaultProxy));
        wethSupplyHarvestVault.initialize(
            address(morpho),
            cEth,
            "MorphoCompoundHarvestWETH",
            "mchWETH",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 50)
        );
        mchWeth = ERC20(address(wethSupplyHarvestVault));

        daiSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        daiSupplyHarvestVault.initialize(
            address(morpho),
            cDai,
            "MorphoCompoundHarvestDAI",
            "mchDAI",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );
        mchDai = ERC20(address(daiSupplyHarvestVault));

        usdcSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        usdcSupplyHarvestVault.initialize(
            address(morpho),
            cUsdc,
            "MorphoCompoundHarvestUSDC",
            "mchUSDC",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 3000, 50)
        );
        mchUsdc = ERC20(address(usdcSupplyHarvestVault));

        createMarket(cComp);
        compSupplyHarvestVault = SupplyHarvestVault(
            address(
                new TransparentUpgradeableProxy(
                    address(supplyHarvestVaultImplV1),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        compSupplyHarvestVault.initialize(
            address(morpho),
            cComp,
            "MorphoCompoundHarvestCOMP",
            "mchCOMP",
            0,
            SupplyHarvestVault.HarvestConfig(3000, 500, 100)
        );
        mchComp = ERC20(address(compSupplyHarvestVault));

        wethSupplyVaultProxy = new TransparentUpgradeableProxy(
            address(supplyVaultImplV1),
            address(proxyAdmin),
            ""
        );
        wethSupplyVault = SupplyVault(address(wethSupplyVaultProxy));
        wethSupplyVault.initialize(address(morpho), cEth, "MorphoCompoundWETH", "mcWETH", 0);
        mcWeth = ERC20(address(wethSupplyVault));

        daiSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        daiSupplyVault.initialize(address(morpho), address(cDai), "MorphoCompoundDAI", "mcDAI", 0);
        mcDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault = SupplyVault(
            address(
                new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")
            )
        );
        usdcSupplyVault.initialize(
            address(morpho),
            address(cUsdc),
            "MorphoCompoundUSDC",
            "mcUSDC",
            0
        );
        mcUsdc = ERC20(address(usdcSupplyVault));
    }

    function initVaultUsers() internal {
        for (uint256 i = 0; i < 3; i++) {
            suppliers[i] = new VaultUser(morpho);
            fillUserBalances(suppliers[i]);
            deal(comp, address(suppliers[i]), INITIAL_BALANCE * WAD);

            vm.label(
                address(suppliers[i]),
                string(abi.encodePacked("VaultSupplier", Strings.toString(i + 1)))
            );
        }

        supplier1 = suppliers[0];
        supplier2 = suppliers[1];
        supplier3 = suppliers[2];

        vaultSupplier1 = VaultUser(payable(suppliers[0]));
        vaultSupplier2 = VaultUser(payable(suppliers[1]));
        vaultSupplier3 = VaultUser(payable(suppliers[2]));
    }

    function setVaultContractsLabels() internal {
        vm.label(address(supplyHarvestVaultImplV1), "SupplyHarvestVaultImplV1");
        vm.label(address(wethSupplyHarvestVault), "SupplyHarvestVault (WETH)");
        vm.label(address(daiSupplyHarvestVault), "SupplyHarvestVault (DAI)");
        vm.label(address(usdcSupplyHarvestVault), "SupplyHarvestVault (USDC)");
        vm.label(address(compSupplyHarvestVault), "SupplyHarvestVault (COMP)");
    }
}
