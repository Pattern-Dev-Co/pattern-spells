// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Ethereum } from "skybase-address-registry/Ethereum.sol";

import { IStarGuardLike } from "src/interfaces/Interfaces.sol";

import { SkybaseEthereum_20260702 } from "./SkybaseEthereum_20260702.sol";

contract SkybaseEthereum_20260702Test is Test {

    SkybaseEthereum_20260702 internal spell;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 24_887_533);

        spell = new SkybaseEthereum_20260702();

        deal(Ethereum.USDS, Ethereum.SKYBASE_PROXY, spell.USDS_TRANSFER_AMOUNT());
    }

    function test_usdsTransfer() public {
        address recipient = Ethereum.SKYBASE_FOUNDATION_OPERATIONAL_MULTISIG;
        uint256 amount      = spell.USDS_TRANSFER_AMOUNT();

        uint256 recipientBalanceBefore = IERC20(Ethereum.USDS).balanceOf(recipient);
        uint256 proxyBalanceBefore     = IERC20(Ethereum.USDS).balanceOf(Ethereum.SKYBASE_PROXY);

        bytes32 bytecodeHash = address(spell).codehash;

        vm.prank(Ethereum.PAUSE_PROXY);
        IStarGuardLike(Ethereum.SKYBASE_STAR_GUARD).plot({
            addr_ : address(spell),
            tag_  : bytecodeHash
        });

        address executed = IStarGuardLike(Ethereum.SKYBASE_STAR_GUARD).exec();
        require(executed == address(spell), "FAILED TO EXECUTE PAYLOAD");

        assertEq(
            IERC20(Ethereum.USDS).balanceOf(recipient),
            recipientBalanceBefore + amount,
            "incorrect-recipient-usds-balance"
        );
        assertEq(
            IERC20(Ethereum.USDS).balanceOf(Ethereum.SKYBASE_PROXY),
            proxyBalanceBefore - amount,
            "incorrect-proxy-usds-balance"
        );
    }
}
