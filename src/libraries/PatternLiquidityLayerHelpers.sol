// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { RateLimitHelpers } from "pattern-alm-controller/src/RateLimitHelpers.sol";

import { IRateLimits } from "pattern-alm-controller/src/interfaces/IRateLimits.sol";

/**
 * @notice Helper functions for Pattern Liquidity Layer
 */
library PatternLiquidityLayerHelpers {

    bytes32 public constant LIMIT_4626_DEPOSIT  = keccak256("LIMIT_4626_DEPOSIT");
    bytes32 public constant LIMIT_4626_WITHDRAW = keccak256("LIMIT_4626_WITHDRAW");
    bytes32 public constant LIMIT_USDS_MINT     = keccak256("LIMIT_USDS_MINT");
    bytes32 public constant LIMIT_USDS_TO_USDC  = keccak256("LIMIT_USDS_TO_USDC");
    bytes32 public constant LIMIT_MAPLE_REDEEM  = keccak256("LIMIT_MAPLE_REDEEM");

    /**
     * @notice Onboard an ERC4626 vault
     * @dev This will set the deposit to the given numbers with
     *      the withdraw limit set to unlimited.
     */
    function onboardERC4626Vault(
        address rateLimits,
        address vault,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            LIMIT_4626_DEPOSIT,
            vault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            LIMIT_4626_WITHDRAW,
            vault
        );
        IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);
        IRateLimits(rateLimits).setUnlimitedRateLimitData(withdrawKey);
    }

    /**
     * @notice Onboard the SyrupUSDC vault
     * @dev This will set the deposit and redeem limits to the given numbers.
     */
    function onboardSyrupUSDCVault(address rateLimits,address syrupUSDCVault,uint256 depositMax,uint256 depositSlope,uint256 redeemMax,uint256 redeemSlope) internal {
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            LIMIT_4626_DEPOSIT,
            syrupUSDCVault
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(LIMIT_MAPLE_REDEEM, syrupUSDCVault);
        IRateLimits(rateLimits).setRateLimitData(depositKey, depositMax, depositSlope);
        IRateLimits(rateLimits).setRateLimitData(withdrawKey, redeemMax, redeemSlope);
    }

    function setUSDSMintRateLimit(
        address rateLimits,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        bytes32 mintKey = LIMIT_USDS_MINT;

        IRateLimits(rateLimits).setRateLimitData(mintKey, maxAmount, slope);
    }

    /**
     * @notice Set the USDSToUSDC rate limit
     * @dev This will set the USDSToUSDC rate limit to the given numbers.
     */
    function setUSDSToUSDCRateLimit(
        address rateLimits,
        uint256 maxUsdcAmount,
        uint256 slope
    ) internal {
        bytes32 usdsToUsdcKey = LIMIT_USDS_TO_USDC;

        IRateLimits(rateLimits).setRateLimitData(usdsToUsdcKey, maxUsdcAmount, slope);
    }

}
