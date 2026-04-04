// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/ObexTestBase.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/obex-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/obex-alm-controller/src/RateLimitHelpers.sol";

import { MainnetController } from "obex-alm-controller/src/MainnetController.sol";

import { IALMProxy }   from "obex-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits } from "obex-alm-controller/src/interfaces/IRateLimits.sol";

import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

import { ObexEthereum_20251113 as ObexSpell } from "./ObexEthereum_20251113.sol";

interface IInvestmentManager {
    function fulfillCancelDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 fulfillment
    ) external;
    function fulfillCancelRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 shares
    ) external;
    function fulfillDepositRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
    function fulfillRedeemRequest(
        uint64 poolId,
        bytes16 trancheId,
        address user,
        uint128 assetId,
        uint128 assets,
        uint128 shares
    ) external;
}

interface ICentrifugeRoot {
    function endorse(address user) external;
}

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function kiss(address) external;
}

interface IPoolManagerLike {
    function updateTranchePrice(uint64 poolId, bytes16 trancheId, uint128 assetId, uint128 price, uint64 computedAt) external;
    function manager() external view returns (address);
    function poolDelegate() external view returns (address);
    function withdrawalManager() external view returns (address);
}

interface IWithdrawalManagerLike {
    function processRedemptions(uint256 maxSharesToProcess) external;
}

interface IPermissionManagerLike {
    function admin() external view returns (address);
    function setLenderAllowlist(address pool, address[] calldata lenders, bool[] calldata booleans) external;
}

interface IMapleGlobalsLike {
    function governor() external view returns (address);
}

interface IMaplePoolManagerLike {
    function poolDelegate() external view returns (address);
    function globals() external view returns (address);
}

interface AutoLineLike {
    function setIlk(
        bytes32 ilk,
        uint256 line,
        uint256 gap,
        uint256 ttl
    ) external;
    function exec(bytes32) external;
}

contract ObexEthereum_20251113Test is ObexTestBase {

    ObexSpell internal OBEX_SPELL = ObexSpell(0xF538909eDF14d2c23002C2b3882Ad60f79d61893);
    address internal DEPLOYER;

    address internal constant MCD_IAM_AUTO_LINE = 0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3;

    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-OBEX-A";

    uint256 constant WAD = 10 ** 18;
    uint256 constant RAD = 10 ** 45;

    IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);



    constructor() {
        id = "20251113";
    }

    function _setupAddresses() internal virtual {
        // DEPLOYER = makeAddr("DEPLOYER");
        // vm.prank(DEPLOYER);
        // OBEX_SPELL = new ObexSpell();
    }

    function setUp() public {
        // November 10, 2025
        setupMainnetDomain({ mainnetForkBlock: 23770489 });
        _setupAddresses();

        vm.startPrank(Ethereum.PAUSE_PROXY);
        IPSMLike(address(controller.psm())).kiss(address(almProxy));
        vm.stopPrank();
    }

    function test_almSystemDeployment() public view {
        assertEq(almProxy.hasRole(0x0, Ethereum.OBEX_PROXY),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Ethereum.OBEX_PROXY), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Ethereum.OBEX_PROXY), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER),   false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),                Ethereum.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()),           Ethereum.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.vault()),                Ethereum.ALLOCATOR_VAULT,      "incorrect-vault");
        assertEq(address(controller.buffer()),               Ethereum.ALLOCATOR_BUFFER,     "incorrect-buffer");
        assertEq(address(controller.psm()),                  Ethereum.PSM,                  "incorrect-psm");
        assertEq(address(controller.daiUsds()),              Ethereum.DAI_USDS,             "incorrect-daiUsds");
        assertEq(address(controller.cctp()),                 Ethereum.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.dai()),                  Ethereum.DAI,                  "incorrect-dai");
        assertEq(address(controller.susde()),                Ethereum.SUSDE,                "incorrect-susde");
        assertEq(address(controller.usdc()),                 Ethereum.USDC,                 "incorrect-usdc");
        assertEq(address(controller.usde()),                 Ethereum.USDE,                 "incorrect-usde");
        assertEq(address(controller.usds()),                 Ethereum.USDS,                 "incorrect-usds");


        assertEq(controller.psmTo18ConversionFactor(), 1e12, "incorrect-psmTo18ConversionFactor");

        IVatLike vat = IVatLike(Ethereum.VAT);

        ( uint256 Art, uint256 rate,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);

        assertEq(Art,  0);
        assertEq(rate, 1e27);
        assertEq(line, 10_000_000e45);

        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.OBEX_PROXY),  0);
    }

    function test_almSystemInitialization() public {
        executeMainnetPayload();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-almProxy");

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");

        assertEq(controller.hasRole(controller.FREEZER(), Ethereum.ALM_FREEZER), true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), Ethereum.ALM_RELAYER), true, "incorrect-relayer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), OBEX_SPELL.OZONE_OEA_RELAYER()), true, "incorrect-relayer-controller for Ozone OEA");

        assertEq(AllocatorVault(Ethereum.ALLOCATOR_VAULT).wards(Ethereum.ALM_PROXY), 1, "incorrect-vault-ward");

        assertEq(IERC20(Ethereum.USDS).allowance(Ethereum.ALLOCATOR_BUFFER, Ethereum.ALM_PROXY), type(uint256).max, "incorrect-usds-allowance");
    }

    function test_basicRateLimits() public {
        _assertRateLimit({
            key: controller.LIMIT_USDS_MINT(),
            maxAmount: 0,
            slope: 0,
            message: "before execution: incorrect-usds-mint-rate-limit"
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 0,
            slope: 0,
            message: "before execution: incorrect-usds-to-usdc-rate-limit"
        });

        executeMainnetPayload();

        _assertRateLimit({
            key: controller.LIMIT_USDS_MINT(),
            maxAmount: 100_000_000e18,
            slope: 50_000_000e18 / uint256(1 days),
            message: "after execution: incorrect-usds-mint-rate-limit"
        });

        _assertRateLimit({
            key: controller.LIMIT_USDS_TO_USDC(),
            maxAmount: 100_000_000e6,
            slope: 50_000_000e6 / uint256(1 days),
            message: "after execution: incorrect-usds-to-usdc-rate-limit"
        });
    }

    function test_SyrupUSDCRateLimitSetup() public {
        _assertRateLimit({
            key: RateLimitHelpers.makeAssetKey(
                controller.LIMIT_4626_DEPOSIT(),
                OBEX_SPELL.SYRUP_USDC_VAULT()
            ),
            maxAmount: 0,
            slope: 0,
            message: "before execution: incorrect-syrup-usdc-deposit-rate-limit"
        });

        _assertRateLimit({
            key: RateLimitHelpers.makeAssetKey(
                controller.LIMIT_MAPLE_REDEEM(),
                OBEX_SPELL.SYRUP_USDC_VAULT()
            ), 
            maxAmount: 0,
            slope: 0,
            message: "before execution: incorrect-syrup-usdc-redeem-rate-limit"
        });

        executeMainnetPayload();

        _assertRateLimit({
            key: RateLimitHelpers.makeAssetKey(
                controller.LIMIT_4626_DEPOSIT(),
                OBEX_SPELL.SYRUP_USDC_VAULT()
            ),
            maxAmount: 100_000_000e6,
            slope: 20_000_000e6 / uint256(1 days),
            message: "after execution: incorrect-syrup-usdc-deposit-rate-limit"
        });

        _assertRateLimit({
            key: RateLimitHelpers.makeAssetKey(
                controller.LIMIT_MAPLE_REDEEM(),
                OBEX_SPELL.SYRUP_USDC_VAULT()
            ),
            maxAmount: type(uint256).max,
            slope: 0,
            message: "after execution: incorrect-syrup-usdc-redeem-rate-limit"
        });
    }

    function test_allocateToSyrupUSDC() public {
        IVatLike vat = IVatLike(Ethereum.VAT);
        IPermissionManagerLike permissionManager = IPermissionManagerLike(0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3);

        // Increase the debt ceiling to allow minting
        vm.prank(Ethereum.PAUSE_PROXY);
        AutoLineLike(MCD_IAM_AUTO_LINE).setIlk({
            ilk:  ALLOCATOR_ILK,
            line: 2_500_000_000 * RAD,  // 2.5B total line
            gap:  250_000_000 * RAD,     // 250M gap
            ttl:  1 days
        });

        executeMainnetPayload();

        // Whitelist ALM_PROXY with Maple permission manager
        address poolManager = IPoolManagerLike(OBEX_SPELL.SYRUP_USDC_VAULT()).manager();
        address poolDelegate = IMaplePoolManagerLike(poolManager).poolDelegate();
        
        address[] memory lenders  = new address[](1);
        bool[]    memory booleans = new bool[](1);
        lenders[0]  = Ethereum.ALM_PROXY;
        booleans[0] = true;

        // Use pool delegate instead of admin (permissions changed after Jan 2025)
        vm.prank(poolDelegate);
        permissionManager.setLenderAllowlist(
            poolManager,
            lenders,
            booleans
        );

        // Execute auto-line to increase ceiling
        AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);

        ( uint256 Art,,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);
        assertEq(Art,  0);
        assertEq(line, 250_000_000 * RAD);  // Should now be 250M

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(100_000_000e18);
        controller.swapUSDSToUSDC(100_000_000e6);
        controller.depositERC4626(OBEX_SPELL.SYRUP_USDC_VAULT(), 100_000_000e6);


        // Verify the allocation worked
        assertGt(IERC20(OBEX_SPELL.SYRUP_USDC_VAULT()).balanceOf(Ethereum.ALM_PROXY), 0, "should have SyrupUSDC shares");
        vm.warp(block.timestamp + 10 days);
        controller.mintUSDS(100_000_000e18);
        // controller.swapUSDSToUSDC(100_000_000e6);
        // controller.depositERC4626(OBEX_SPELL.SYRUP_USDC_VAULT(), 100_000_000e6);
        vm.stopPrank();
    }

    function test_redeemSyrupUSDC() public {
        IVatLike vat = IVatLike(Ethereum.VAT);
        IPermissionManagerLike permissionManager = IPermissionManagerLike(0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3);

        // Increase the debt ceiling to allow minting
        vm.prank(Ethereum.PAUSE_PROXY);
        AutoLineLike(MCD_IAM_AUTO_LINE).setIlk({
            ilk:  ALLOCATOR_ILK,
            line: 2_500_000_000 * RAD,  // 2.5B total line
            gap:  250_000_000 * RAD,     // 250M gap
            ttl:  1 days
        });

        executeMainnetPayload();

        // Whitelist ALM_PROXY with Maple permission manager
        address poolManager = IPoolManagerLike(OBEX_SPELL.SYRUP_USDC_VAULT()).manager();
        address poolDelegate = IMaplePoolManagerLike(poolManager).poolDelegate();
        
        address[] memory lenders  = new address[](1);
        bool[]    memory booleans = new bool[](1);
        lenders[0]  = Ethereum.ALM_PROXY;
        booleans[0] = true;

        // Use pool delegate instead of admin (permissions changed after Jan 2025)
        vm.prank(poolDelegate);
        permissionManager.setLenderAllowlist(
            poolManager,
            lenders,
            booleans
        );

        // Execute auto-line to increase ceiling
        AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);

        ( uint256 Art,,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);
        assertEq(Art,  0);
        assertEq(line, 250_000_000 * RAD);  // Should now be 250M

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(100_000_000e18);
        controller.swapUSDSToUSDC(100_000_000e6);
        uint256 shares = controller.depositERC4626(OBEX_SPELL.SYRUP_USDC_VAULT(), 100_000_000e6);
        assertGt(shares, 0, "should have SyrupUSDC shares");

        address manager = IPoolManagerLike(OBEX_SPELL.SYRUP_USDC_VAULT()).manager();
        uint256 withdrawalManagerSharesBefore = IERC20(OBEX_SPELL.SYRUP_USDC_VAULT()).balanceOf(IPoolManagerLike(manager).withdrawalManager());

        controller.requestMapleRedemption(OBEX_SPELL.SYRUP_USDC_VAULT(), shares);
        assertEq(IERC20(OBEX_SPELL.SYRUP_USDC_VAULT()).balanceOf(Ethereum.ALM_PROXY), 0, "should have no SyrupUSDC shares");
        assertEq(IERC20(OBEX_SPELL.SYRUP_USDC_VAULT()).balanceOf(IPoolManagerLike(manager).withdrawalManager()), withdrawalManagerSharesBefore + shares, "should have SyrupUSDC shares in withdrawal manager");
        vm.stopPrank();
        
        address USDC = Ethereum.USDC;
        uint256 proxyBalanceBefore = IERC20(USDC).balanceOf(Ethereum.ALM_PROXY);
        //prank as the withdrawal manager to process the redemptions
        IWithdrawalManagerLike withdrawalManager = IWithdrawalManagerLike(IPoolManagerLike(manager).withdrawalManager());
        vm.startPrank(address(poolDelegate));
        withdrawalManager.processRedemptions(shares);
        vm.stopPrank();

        uint256 proxyBalanceAfter = IERC20(USDC).balanceOf(Ethereum.ALM_PROXY);
        assertEq(proxyBalanceAfter, proxyBalanceBefore + 100_000_000 * 1e6 - 1, "should have USDC in proxy");
    }

    // function test_centrifugeVaultOnboarding() public {
    //     _testCentrifugeOnboarding(
    //         CENTRIFUGE_VAULT,
    //         CENTRIFUGE_VAULT_TOKEN,
    //         CENTRIFUGE_CONFIG,
    //         100_000_000e6,
    //         100_000_000e6,
    //         50_000_000e6 / uint256(1 days)
    //     );
    // }

    // function test_ongoingCentrifugeDeposits() public {
    //     IVatLike vat = IVatLike(Ethereum.VAT);

    //     uint256 dailyDepositAmount = 50_000_000;
    //     bytes32 depositKey = RateLimitHelpers.makeAssetKey(
    //         controller.LIMIT_7540_DEPOSIT(),
    //         CENTRIFUGE_VAULT
    //     );

    //     vm.prank(Ethereum.PAUSE_PROXY);
    //     AutoLineLike(MCD_IAM_AUTO_LINE).setIlk({
    //         ilk:  ALLOCATOR_ILK,
    //         line: 2_500_000_000 * RAD,
    //         gap:  50_000_000 * RAD,
    //         ttl:  1 days
    //     });

    //     executeMainnetPayload();

    //     AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);

    //     ( uint256 Art,,, uint256 line, ) = vat.ilks(ALLOCATOR_ILK);

    //     assertEq(Art,  0);
    //     assertEq(line, 50_000_000 * RAD);

    //     for (uint256 i = 0; i < 20; i++) {
    //         // The price of the centrifuge vault share is set to 2.0 in the test base
    //         assertEq(IERC20(CENTRIFUGE_VAULT_TOKEN).balanceOf(Ethereum.ALM_PROXY), (dailyDepositAmount * 1e6 / 2) * i);

    //         (Art,,, line, ) = vat.ilks(ALLOCATOR_ILK);
    //         assertEq(Art, (dailyDepositAmount * WAD) * i);

    //         assertEq(rateLimits.getCurrentRateLimit(depositKey), 100_000_000e6);

    //         AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);
    //         _centrifugeDeposit(dailyDepositAmount * 1e6);

    //         // The price of the centrifuge vault share is set to 2.0 in the test base
    //         assertEq(IERC20(CENTRIFUGE_VAULT_TOKEN).balanceOf(Ethereum.ALM_PROXY), (dailyDepositAmount * 1e6 / 2) * (i + 1));

    //         (Art,,, line, ) = vat.ilks(ALLOCATOR_ILK);
    //         assertEq(Art,  (dailyDepositAmount * WAD) * (i + 1));
    //         assertEq(line, (dailyDepositAmount * RAD) * (i + 1));

    //         assertEq(rateLimits.getCurrentRateLimit(depositKey), 50_000_000e6);

    //         vm.roll(block.number + 1);
    //         vm.warp(block.timestamp + 1 days + 1);
    //     }

    //     AutoLineLike(MCD_IAM_AUTO_LINE).exec(ALLOCATOR_ILK);

    //     (Art,,, line, ) = vat.ilks(ALLOCATOR_ILK);
    //     assertEq(Art,  1_000_000_000 * WAD);
    //     assertEq(line, 1_050_000_000 * RAD);

    //     // The price of the centrifuge vault share is set to 2.0 in the test base
    //     assertEq(IERC20(CENTRIFUGE_VAULT_TOKEN).balanceOf(Ethereum.ALM_PROXY), 1_000_000_000 / 2 * 1e6);
    // }

    // function _centrifugeDeposit(uint256 depositAmount) internal {
    //     vm.startPrank(Ethereum.ALM_RELAYER);
    //     controller.mintUSDS(depositAmount * 1e12);
    //     controller.swapUSDSToUSDC(depositAmount);
    //     controller.requestDepositERC7540(CENTRIFUGE_VAULT, depositAmount);
    //     vm.stopPrank();

    //     _centrifugeFulfillDepositRequest(
    //         CENTRIFUGE_CONFIG,
    //         depositAmount
    //     );

    //     vm.prank(Ethereum.ALM_RELAYER);
    //     controller.claimDepositERC7540(CENTRIFUGE_VAULT);
    // }

}
