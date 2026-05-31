// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum } from "skybase-address-registry/Ethereum.sol";

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";

import { SpellRunner } from "./SpellRunner.sol";

abstract contract CommonSpellAssertions is SpellRunner {
    using DomainHelpers for Domain;

    function test_payloadBytecodeMatches() public {
        _assertPayloadBytecodeMatches();
    }

    function _assertPayloadBytecodeMatches() private {
        mainnet.domain.selectFork();

        address actualPayload = mainnet.payload;
        vm.skip(actualPayload == address(0));
        require(_isContract(actualPayload), "PAYLOAD IS NOT A CONTRACT");

        address expectedPayload = deployPayload();
        require(_isContract(expectedPayload), "EXPECTED PAYLOAD IS NOT A CONTRACT");

        uint256 expectedBytecodeSize = expectedPayload.code.length;
        uint256 actualBytecodeSize   = actualPayload.code.length;

        uint256 metadataLength = _getBytecodeMetadataLength(expectedPayload);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = _getBytecodeMetadataLength(actualPayload);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);

        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;

        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedPayload, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualPayload, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }

        assertEq(actualHash, expectedHash);
    }

    function _getBytecodeMetadataLength(address a) internal view returns (uint256 length) {
        assembly {
            let ptr  := mload(0x40)
            let size := extcodesize(a)
            if iszero(lt(size, 2)) {
                extcodecopy(a, ptr, sub(size, 2), 2)
                length := mload(ptr)
                length := shr(240, length)
                length := add(length, 2)
            }
        }
    }

    function _assertSkybaseProxyUsdsBalance(uint256 expected) internal view {
        assertEq(
            IERC20(Ethereum.USDS).balanceOf(Ethereum.SKYBASE_PROXY),
            expected,
            "incorrect-skybase-proxy-usds-balance"
        );
    }
}
