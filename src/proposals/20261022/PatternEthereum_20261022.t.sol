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

    // River offramp wallet, must equal the address hardcoded in the 20261022 payload.
    // TODO: Replace with the actual river offramp address from the Pattern-Address-Registry
    address internal constant RIVER_OFFRAMP_ADDRESS = 0x0000000000000000000000000000000000000001;

    uint256 internal constant RIVER_TRANSFER_MAX   = 35_000_000e6;
    uint256 internal constant RIVER_TRANSFER_SLOPE = 10_000_000e6 / uint256(1 days);

    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
    IERC20            usdc       = IERC20(Ethereum.USDC);
    IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);

    constructor() {
        id = "20261022";
    }

    function _setupAddresses() internal virtual {
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
