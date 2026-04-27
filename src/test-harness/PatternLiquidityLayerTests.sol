// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Ethereum }  from "pattern-address-registry/Ethereum.sol";

import { IALMProxy }         from "pattern-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "pattern-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "pattern-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "pattern-alm-controller/src/RateLimitHelpers.sol";

import { PatternLiquidityLayerHelpers } from "src/libraries/PatternLiquidityLayerHelpers.sol";

import { ChainId, ChainIdUtils } from "../libraries/ChainId.sol";

import { SpellRunner } from "./SpellRunner.sol";

struct PatternLiquidityLayerContext {
    address     controller;
    IALMProxy   proxy;
    IRateLimits rateLimits;
    address     relayer;
    address     freezer;
}


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
    function poolManager() external view returns (address);
}

interface IPoolManager {
    function assetToId(address asset) external view returns (uint128);
}


abstract contract PatternLiquidityLayerTests is SpellRunner {

    function _getPatternLiquidityLayerContext(ChainId chain) internal view returns(PatternLiquidityLayerContext memory ctx) {
        address controller;
        if(chainData[chain].spellExecuted) {
            controller = chainData[chain].newController;
        } else {
            controller = chainData[chain].prevController;
        }
        if (chain == ChainIdUtils.Ethereum()) {
            ctx = PatternLiquidityLayerContext(
                controller,
                IALMProxy(Ethereum.ALM_PROXY),
                IRateLimits(Ethereum.ALM_RATE_LIMITS),
                Ethereum.ALM_RELAYER,
                Ethereum.ALM_FREEZER
        );
        } else {
            revert("Chain not supported by PatternLiquidityLayerTests context");
        }
    }

    function _getPatternLiquidityLayerContext() internal view returns(PatternLiquidityLayerContext memory) {
        return _getPatternLiquidityLayerContext(ChainIdUtils.fromUint(block.chainid));
    }

   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope
   ) internal view {
       _assertRateLimit(key, maxAmount, slope, "");
   }
   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope,
       string memory message
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getPatternLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, maxAmount, message);
        assertEq(rateLimit.slope,     slope, message);
    }

   function _assertUnlimitedRateLimit(
       bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getPatternLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, type(uint256).max);
        assertEq(rateLimit.slope,     0);
    }

    function _assertZeroRateLimit(
        bytes32 key
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getPatternLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount, 0);
        assertEq(rateLimit.slope,     0);
    }

   function _assertRateLimit(
       bytes32 key,
       uint256 maxAmount,
       uint256 slope,
       uint256 lastAmount,
       uint256 lastUpdated
    ) internal view {
        IRateLimits.RateLimitData memory rateLimit = _getPatternLiquidityLayerContext().rateLimits.getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  lastAmount);
        assertEq(rateLimit.lastUpdated, lastUpdated);
    }

    function _testERC4626Onboarding(
        address vault,
        uint256 expectedDepositAmount,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        PatternLiquidityLayerContext memory ctx = _getPatternLiquidityLayerContext();
        bool unlimitedDeposit = depositMax == type(uint256).max;

        // Note: ERC4626 signature is the same for mainnet and foreign
        deal(IERC4626(vault).asset(), address(ctx.proxy), expectedDepositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            PatternLiquidityLayerHelpers.LIMIT_4626_DEPOSIT,
            vault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            PatternLiquidityLayerHelpers.LIMIT_4626_WITHDRAW,
            vault
        );

        _assertZeroRateLimit(depositKey);
        _assertZeroRateLimit(withdrawKey);

        vm.prank(ctx.relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        executeAllPayloadsAndBridges();

        // Reload the context after spell execution to get the new controller after potential controller upgrade
        ctx = _getPatternLiquidityLayerContext();

        _assertRateLimit(depositKey, depositMax, depositSlope);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        if (!unlimitedDeposit) {
            vm.prank(ctx.relayer);
            vm.expectRevert("RateLimits/rate-limit-exceeded");
            MainnetController(ctx.controller).depositERC4626(vault, depositMax + 1);
        }

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  depositMax);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).depositERC4626(vault, expectedDepositAmount);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(ctx.relayer);
        MainnetController(ctx.controller).withdrawERC4626(vault, expectedDepositAmount / 2);

        assertEq(ctx.rateLimits.getCurrentRateLimit(depositKey),  unlimitedDeposit ? type(uint256).max : depositMax - expectedDepositAmount);
        assertEq(ctx.rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        if (!unlimitedDeposit) {
            // Do some sanity checks on the slope
            // This is to catch things like forgetting to divide to a per-second time, etc

            // We assume it takes at least 1 day to recharge to max
            uint256 dailySlope = depositSlope * 1 days;
            assertLe(dailySlope, depositMax);

            // It shouldn"t take more than 30 days to recharge to max
            uint256 monthlySlope = depositSlope * 30 days;
            assertGe(monthlySlope, depositMax);
        }
    }






    // function _testControllerUpgrade(address oldController, address newController) internal {
    //     ChainId currentChain = ChainIdUtils.fromUint(block.chainid);

    //     PatternLiquidityLayerContext memory ctx = _getPatternLiquidityLayerContext();

    //     // Note the functions used are interchangable with mainnet and foreign controllers
    //     MainnetController controller = MainnetController(newController);

    //     bytes32 CONTROLLER = ctx.proxy.CONTROLLER();
    //     bytes32 RELAYER    = controller.RELAYER();
    //     bytes32 FREEZER    = controller.FREEZER();

    //     assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), true);
    //     assertEq(ctx.proxy.hasRole(CONTROLLER, newController), false);

    //     assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), true);
    //     assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), false);

    //     assertEq(controller.hasRole(RELAYER, ctx.relayer), false);
    //     assertEq(controller.hasRole(FREEZER, ctx.freezer), false);

    //     if (currentChain == ChainIdUtils.Ethereum()) {
    //         assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE), bytes32(uint256(uint160(address(0)))));
    //     } else {
    //         assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),  bytes32(uint256(uint160(address(0)))));
    //     }

    //     if (currentChain == ChainIdUtils.Ethereum()) {
    //         assertEq(controller.centrifugeRecipients(PatternLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID), bytes32(uint256(uint160(address(0)))));
    //     } else {
    //         assertEq(controller.centrifugeRecipients(PatternLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID), bytes32(uint256(uint160(address(0)))));
    //     }

    //     executeAllPayloadsAndBridges();

    //     assertEq(ctx.proxy.hasRole(CONTROLLER, oldController), false);
    //     assertEq(ctx.proxy.hasRole(CONTROLLER, newController), true);

    //     assertEq(ctx.rateLimits.hasRole(CONTROLLER, oldController), false);
    //     assertEq(ctx.rateLimits.hasRole(CONTROLLER, newController), true);

    //     assertEq(controller.hasRole(RELAYER, ctx.relayer), true);
    //     assertEq(controller.hasRole(FREEZER, ctx.freezer), true);

    //     if (currentChain == ChainIdUtils.Ethereum()) {
    //         assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE), bytes32(uint256(uint160(Avalanche.ALM_PROXY))));
    //     } else {
    //         assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),  bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    //     }

    //     if (currentChain == ChainIdUtils.Ethereum()) {
    //         assertEq(controller.centrifugeRecipients(PatternLiquidityLayerHelpers.AVALANCHE_DESTINATION_CENTRIFUGE_ID), bytes32(uint256(uint160(Avalanche.ALM_PROXY))));
    //     } else {
    //         assertEq(controller.centrifugeRecipients(PatternLiquidityLayerHelpers.ETHEREUM_DESTINATION_CENTRIFUGE_ID), bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    //     }
    // }

}
