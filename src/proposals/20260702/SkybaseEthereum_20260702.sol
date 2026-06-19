// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Ethereum } from "skybase-address-registry/Ethereum.sol";

import { SkybasePayloadEthereum } from "src/libraries/SkybasePayloadEthereum.sol";

/**
 * @title   July 02, 2026 Skybase Ethereum Proposal
 * @author  Soter Labs
 * @notice  Transfer Skybase Foundation Grant
 * Forum    https://forum.skyeco.com/t/june-4-2026-proposed-changes-to-spark-for-upcoming-spell/27931
 */
contract SkybaseEthereum_20260702 is SkybasePayloadEthereum {

    uint256 public constant USDS_TRANSFER_AMOUNT = 700_000e18;

    function _execute() internal override {
        IERC20(Ethereum.USDS).transfer(Ethereum.SKYBASE_FOUNDATION_OPERATIONAL_MULTISIG, USDS_TRANSFER_AMOUNT);
    }
}
