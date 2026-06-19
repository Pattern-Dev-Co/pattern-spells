// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "skybase-address-registry/Ethereum.sol";

import { SkybaseTestBase } from "src/test-harness/SkybaseTestBase.sol";

import { SkybaseEthereum_20260702 } from "./SkybaseEthereum_20260702.sol";

contract SkybaseEthereum_20260702Test is SkybaseTestBase {

    address internal sender = Ethereum.SKYBASE_PROXY;

    constructor() {
        id = "20260702";
    }

    function setUp() public {
        // April 16, 2026
        setupMainnetDomain(24_887_533);
    }

    function test_usdsTransfer() public {
        SkybaseEthereum_20260702 spell = SkybaseEthereum_20260702(mainnet.payload);

        address recipient = Ethereum.SKYBASE_FOUNDATION_OPERATIONAL_MULTISIG;
        uint256 amount      = spell.USDS_TRANSFER_AMOUNT();

        uint256 recipientBalanceBefore = IERC20(Ethereum.USDS).balanceOf(recipient);
        uint256 proxyBalanceBefore     = IERC20(Ethereum.USDS).balanceOf(sender);

        assertGe(proxyBalanceBefore, amount, "insufficient-skybase-proxy-usds-balance");
        _assertSkybaseProxyUsdsBalance(proxyBalanceBefore);

        executeMainnetPayload();

        assertEq(
            IERC20(Ethereum.USDS).balanceOf(recipient),
            recipientBalanceBefore + amount,
            "incorrect-recipient-usds-balance"
        );
        _assertSkybaseProxyUsdsBalance(proxyBalanceBefore - amount);
    }
}
