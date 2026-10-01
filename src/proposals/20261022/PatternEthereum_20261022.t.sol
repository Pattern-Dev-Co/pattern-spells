// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "src/test-harness/PatternTestBase.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "lib/pattern-address-registry/src/Ethereum.sol";

import { RateLimitHelpers } from "lib/pattern-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits }       from "pattern-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "pattern-alm-controller/src/MainnetController.sol";

import { PatternEthereum_20261022 as PatternSpell } from "./PatternEthereum_20261022.sol";

import { ChainIdUtils } from "../../libraries/ChainId.sol";

contract PatternEthereum_20261022Test is PatternTestBase {

    PatternSpell internal PATTERN_SPELL;
    address internal DEPLOYER;

    // River offramp wallet, must equal the address in the 20261022 payload.
    address internal constant RIVER_OFFRAMP_ADDRESS = 0xfD2cB7Ebbb339B9AA4E9C60e5aFa460F4888320F;

    uint256 internal constant RIVER_TRANSFER_MAX   = 35_000_000e6;
    uint256 internal constant RIVER_TRANSFER_SLOPE = 10_000_000e6 / uint256(1 days);

    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
    IERC20            usdc       = IERC20(Ethereum.USDC);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);

    constructor() {
        id = "20261022";
    }

    function _setupAddresses() internal virtual {
        // Pattern Deployer
        DEPLOYER  = 0x86865836187fD889B7AE65027056F3Fb43312018;

        vm.prank(DEPLOYER);
        PATTERN_SPELL = new PatternSpell();
    }

    function setUp() public {
        // September 23, 2026
        setupMainnetDomain({ mainnetForkBlock: 26041033 });
        _setupAddresses();

        chainData[ChainIdUtils.Ethereum()].payload = address(PATTERN_SPELL);
    }

    // Checks the exact `setRateLimitData(key, maxAmount, slope)` arguments against hardcoded literals,
    // independently of the helpers and constants used by the payload.
    function test_riverTransferAssetRateLimitArguments() public {
        bytes32 expectedKey       = 0x9e89eef868db62cc103dac9e8428957603e3ff835526132d10b5f1f327fc7605;
        uint256 expectedMaxAmount = 35000000000000;  // 35,000,000 USDC
        uint256 expectedSlope     = 115740740;       // 10,000,000 USDC per day, rounded down

        // Key inputs
        bytes32 limitAssetTransferKey = controller.LIMIT_ASSET_TRANSFER();

        assertEq(
            limitAssetTransferKey,
            0x48f98264e3feb9c04c94251c86b84a95f369fb2973906e457f22ec9080cb6755,
            "incorrect-limit-asset-transfer"
        );
        assertEq(limitAssetTransferKey, keccak256("LIMIT_ASSET_TRANSFER"), "incorrect-limit-asset-transfer-preimage");

        assertEq(Ethereum.USDC,                         0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "incorrect-usdc");
        assertEq(Ethereum.RIVER_SPV_2_OFFRAMP,          0xfD2cB7Ebbb339B9AA4E9C60e5aFa460F4888320F, "incorrect-registry-river-offramp");
        assertEq(PATTERN_SPELL.RIVER_OFFRAMP_ADDRESS(), 0xfD2cB7Ebbb339B9AA4E9C60e5aFa460F4888320F, "incorrect-payload-river-offramp");

        // Key derivation
        assertEq(
            keccak256(
                abi.encode(
                    bytes32(0x48f98264e3feb9c04c94251c86b84a95f369fb2973906e457f22ec9080cb6755),
                    address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
                    address(0xfD2cB7Ebbb339B9AA4E9C60e5aFa460F4888320F)
                )
            ),
            expectedKey,
            "incorrect-key-derivation"
        );
        assertEq(
            RateLimitHelpers.makeAssetDestinationKey(limitAssetTransferKey, Ethereum.USDC, RIVER_OFFRAMP_ADDRESS),
            expectedKey,
            "incorrect-helper-key"
        );

        // Amount derivation
        assertEq(usdc.decimals(),                6,                 "incorrect-usdc-decimals");
        assertEq(10_000_000e6 / uint256(1 days), expectedSlope,     "incorrect-slope-derivation");
        assertEq(RIVER_TRANSFER_MAX,             expectedMaxAmount, "incorrect-max-amount-constant");
        assertEq(RIVER_TRANSFER_SLOPE,           expectedSlope,     "incorrect-slope-constant");

        _assertZeroRateLimit(expectedKey);

        // The payload must make exactly one call with exactly these arguments
        vm.expectCall(
            Ethereum.ALM_RATE_LIMITS,
            abi.encodeWithSignature("setRateLimitData(bytes32,uint256,uint256)", expectedKey, expectedMaxAmount, expectedSlope),
            1
        );

        executeMainnetPayload();

        IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(expectedKey);

        assertEq(data.maxAmount,   expectedMaxAmount, "after execution: incorrect-max-amount");
        assertEq(data.slope,       expectedSlope,     "after execution: incorrect-slope");
        assertEq(data.lastAmount,  expectedMaxAmount, "after execution: incorrect-last-amount");
        assertEq(data.lastUpdated, block.timestamp,   "after execution: incorrect-last-updated");
    }

    function test_riverTransferAssetAllocation() public {
        bytes32 transferAssetKey = RateLimitHelpers.makeAssetDestinationKey(
            controller.LIMIT_ASSET_TRANSFER(),
            Ethereum.USDC,
            RIVER_OFFRAMP_ADDRESS
        );

        _assertZeroRateLimit(transferAssetKey);

        executeMainnetPayload();

        _assertRateLimit({
            key:       transferAssetKey,
            maxAmount: RIVER_TRANSFER_MAX,
            slope:     RIVER_TRANSFER_SLOPE,
            message:   "after execution: incorrect-river-transfer-asset-allocation"
        });

        _checkRateLimitValue(transferAssetKey, 6);

        // A freshly set rate limit starts full
        assertEq(rateLimits.getCurrentRateLimit(transferAssetKey), RIVER_TRANSFER_MAX, "after execution: limit-not-full");

        uint256 riverBalance = usdc.balanceOf(RIVER_OFFRAMP_ADDRESS);

        /*******************************************************/
        /*** Step 1: Partial transfer of 10m, limit drops     ***/
        /*******************************************************/

        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(10_000_000e18);
        controller.swapUSDSToUSDC(10_000_000e6);
        controller.transferAsset(Ethereum.USDC, RIVER_OFFRAMP_ADDRESS, 10_000_000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(RIVER_OFFRAMP_ADDRESS), riverBalance + 10_000_000e6, "step 1: incorrect-balance-delta");
        assertEq(
            rateLimits.getCurrentRateLimit(transferAssetKey),
            RIVER_TRANSFER_MAX - 10_000_000e6,
            "step 1: incorrect-remaining-limit"
        );
        riverBalance = usdc.balanceOf(RIVER_OFFRAMP_ADDRESS);

        /*******************************************************/
        /*** Step 2: One day recharges 10m, back to the cap   ***/
        /*******************************************************/

        skip(1 days + 1 seconds);  // +1 second due to rounding

        assertEq(
            rateLimits.getCurrentRateLimit(transferAssetKey),
            RIVER_TRANSFER_MAX,
            "step 2: limit-not-recharged-to-max"
        );

        /*******************************************************/
        /*** Step 3: Over the cap reverts, full 35m succeeds  ***/
        /*******************************************************/

        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.mintUSDS(35_000_000e18);
        controller.swapUSDSToUSDC(35_000_000e6);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.transferAsset(Ethereum.USDC, RIVER_OFFRAMP_ADDRESS, RIVER_TRANSFER_MAX + 1);

        controller.transferAsset(Ethereum.USDC, RIVER_OFFRAMP_ADDRESS, RIVER_TRANSFER_MAX);
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(RIVER_OFFRAMP_ADDRESS),
            riverBalance + RIVER_TRANSFER_MAX,
            "step 3: incorrect-balance-delta"
        );
        assertEq(rateLimits.getCurrentRateLimit(transferAssetKey), 0, "step 3: limit-not-exhausted");

        /*******************************************************/
        /*** Step 4: Slope recharges 10m per day, capped      ***/
        /*******************************************************/

        skip(1 days);

        assertEq(
            rateLimits.getCurrentRateLimit(transferAssetKey),
            RIVER_TRANSFER_SLOPE * 1 days,
            "step 4: incorrect-slope-recharge"
        );

        skip(3 days);

        assertEq(rateLimits.getCurrentRateLimit(transferAssetKey), RIVER_TRANSFER_MAX, "step 4: limit-not-capped-at-max");
    }

}
