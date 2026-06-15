// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Ethereum } from "skybase-address-registry/Ethereum.sol";

import { SkybasePayloadEthereum } from "src/libraries/SkybasePayloadEthereum.sol";

/**
 * @title   July 02, 2026 Skybase Ethereum Proposal
 * @notice  Transfer excess USDS from the Skybase proxy.
 * @author  Soter Labs
 */
contract SkybaseEthereum_20260702 is SkybasePayloadEthereum {

    /// @dev Set recipient and amount before deployment.
    address public constant SKYBASE_FOUNDATION_MULTISIG     = 0x58B945c8Ce34BD8cEA3Fc0437626F9F87d58A621;
    uint256 public constant USDS_TRANSFER_AMOUNT = 700_000e18;

    function _execute() internal override {
        IERC20(Ethereum.USDS).transfer(SKYBASE_FOUNDATION_MULTISIG, USDS_TRANSFER_AMOUNT);
    }
}
