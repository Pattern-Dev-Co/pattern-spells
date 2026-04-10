// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { PatternPayloadEthereum } from "src/libraries/PatternPayloadEthereum.sol";

import { Ethereum } from "lib/pattern-address-registry/src/Ethereum.sol";

import { MainnetControllerInit, ControllerInstance } from "lib/pattern-alm-controller/deploy/MainnetControllerInit.sol";

/**
 * @title    April 23, 2026 Pattern Ethereum Proposal
 * @notice Activate Pattern Liquidity Layer - initiate ALM system, set rate limits, onboard SyrupUSDC
 * @author Pattern Labs
 * Forum Post: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
 * Vote Link:  TODO:
 */
contract PatternEthereum_20260423 is PatternPayloadEthereum {

    address public constant SYRUP_USDC_VAULT = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;

    uint256 internal constant INITIAL_USDS_MINT_MAX   = 100_000_000e18;
    uint256 internal constant INITIAL_USDS_MINT_SLOPE = 50_000_000e18 / uint256(1 days);

    uint256 internal constant INITIAL_USDS_TO_USDC_MAX   = 100_000_000e6;
    uint256 internal constant INITIAL_USDS_TO_USDC_SLOPE = 50_000_000e6 / uint256(1 days);

    uint256 internal constant INITIAL_SYRUP_USDC_DEPOSIT_MAX   = 100_000_000e6;
    uint256 internal constant INITIAL_SYRUP_USDC_DEPOSIT_SLOPE = 20_000_000e6 / uint256(1 days);

    uint256 internal constant INITIAL_SYRUP_USDC_REDEEM_MAX = type(uint256).max;


    function _execute() internal override {

        // Initialize ALM System
        // Forum: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
        // Poll: TODO:
        _initiateAlmSystem();

        // Initialize ALM System (USDS Mint and USDS to USDC Conversion)
        // Forum: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
        // Poll: TODO:
        _setupBasicRateLimits();

        // Onboard Syrup USDC Vault (Deposit and Redeem)
        // Forum: https://forum.skyeco.com/t/proposed-changes-to-pattern-for-upcoming-spell/27835
        // Poll: TODO:
        _onboardSyrupUSDCVault();
    }

    function _initiateAlmSystem() private {
        address[] memory relayers = new address[](1);
        relayers[0] = Ethereum.ALM_RELAYER;

        MainnetControllerInit.initAlmSystem({
            vault: Ethereum.ALLOCATOR_VAULT,
            usds: Ethereum.USDS,
            controllerInst: ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : Ethereum.ALM_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            configAddresses: MainnetControllerInit.ConfigAddressParams({
                freezer       : Ethereum.ALM_FREEZER,
                relayers      : relayers,
                oldController : address(0)
            }),
            checkAddresses: MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.PATTERN_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients:       new MainnetControllerInit.MintRecipient[](0),
            layerZeroRecipients:  new MainnetControllerInit.LayerZeroRecipient[](0),
            centrifugeRecipients: new MainnetControllerInit.CentrifugeRecipient[](0)
        });
    }

    function _setupBasicRateLimits() private {
        _setUSDSMintRateLimit(
            INITIAL_USDS_MINT_MAX,
            INITIAL_USDS_MINT_SLOPE
        );
        _setUSDSToUSDCRateLimit(
            INITIAL_USDS_TO_USDC_MAX,
            INITIAL_USDS_TO_USDC_SLOPE
        );
    }

    function _onboardSyrupUSDCVault() private {
         _onboardSyrupUSDCVault({
            syrupUSDCVault: SYRUP_USDC_VAULT,
            depositMax:     INITIAL_SYRUP_USDC_DEPOSIT_MAX,
            depositSlope:   INITIAL_SYRUP_USDC_DEPOSIT_SLOPE,
            redeemMax:      INITIAL_SYRUP_USDC_REDEEM_MAX,
            redeemSlope:    0
         });
    }
}
