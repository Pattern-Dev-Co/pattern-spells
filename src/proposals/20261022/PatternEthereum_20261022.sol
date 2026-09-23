// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { Ethereum } from "lib/pattern-address-registry/src/Ethereum.sol";

import { MainnetController } from "pattern-alm-controller/src/MainnetController.sol";
import { RateLimitHelpers }  from "pattern-alm-controller/src/RateLimitHelpers.sol";

import { PatternPayloadEthereum }       from "src/libraries/PatternPayloadEthereum.sol";
import { PatternLiquidityLayerHelpers } from "src/libraries/PatternLiquidityLayerHelpers.sol";

/**
 * @title      October 22, 2026 Pattern Ethereum Proposal
 * @notice     Pattern River Allocation - Onboard Transfer Asset
 * @author     Pattern Labs
 * Forum Post: https://forum.skyeco.com/t/<TBD>
 * Vote Link:  https://vote.sky.money/polling/<TBD>
 */
contract PatternEthereum_20261022 is PatternPayloadEthereum {

    // River offramp wallet, must equal the address hardcoded in the 20261022 test.
    // TODO: Replace with the actual river offramp address from the Pattern-Address-Registry
    address public constant RIVER_OFFRAMP_ADDRESS = 0x0000000000000000000000000000000000000001;

    function _execute() internal override {
        // Onboard River Transfer Asset
        // Forum: https://forum.skyeco.com/t/<TBD>
        // Poll:  https://vote.sky.money/polling/<TBD>
        _onboardRiverTransferAssetAllocation();
    }

    function _onboardRiverTransferAssetAllocation() private {
        PatternLiquidityLayerHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetDestinationKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_ASSET_TRANSFER(),
                Ethereum.USDC,
                RIVER_OFFRAMP_ADDRESS
            ),
            Ethereum.ALM_RATE_LIMITS,
            35_000_000e6,                   // BEFORE: 0
            10_000_000e6 / uint256(1 days), // BEFORE: 0
            6
        );
    }
}
