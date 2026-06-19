// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test }      from "forge-std/Test.sol";
import { StdChains } from "forge-std/StdChains.sol";
import { console }   from "forge-std/console.sol";

import { Ethereum } from "skybase-address-registry/Ethereum.sol";

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";

import { IStarGuardLike } from "src/interfaces/Interfaces.sol";

import { SkybasePayloadEthereum } from "src/libraries/SkybasePayloadEthereum.sol";

abstract contract SpellRunner is Test {
    using DomainHelpers for Domain;
    using DomainHelpers for StdChains.Chain;

    struct MainnetData {
        address payload;
        Domain  domain;
        bool    spellExecuted;
    }

    MainnetData internal mainnet;
    string      internal id;

    /// @dev Fork mainnet at a specific block and optionally deploy the spell from `out/`.
    function setupMainnetDomain(uint256 mainnetForkBlock) internal {
        mainnet.domain = getChain("mainnet").createFork(mainnetForkBlock);
        mainnet.domain.selectFork();
        deployPayloads();
    }

    function spellIdentifier() private view returns (string memory) {
        string memory slug = string(abi.encodePacked("SkybaseEthereum_", id));
        return string(abi.encodePacked(slug, ".sol:", slug));
    }

    function deployPayload() internal returns (address) {
        mainnet.domain.selectFork();
        return deployCode(spellIdentifier());
    }

    function deployPayloads() internal {
        string memory identifier = spellIdentifier();
        try vm.getCode(identifier) {
            mainnet.payload = deployPayload();
            mainnet.spellExecuted = false;
            console.log("deployed payload for network: Ethereum");
            console.log("             payload address: ", mainnet.payload);
        } catch {
            console.log("skipping spell deployment for network: Ethereum");
        }
    }

    function executeMainnetPayload() internal {
        mainnet.domain.selectFork();

        address payloadAddress = mainnet.payload;
        require(_isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");
        require(SkybasePayloadEthereum(payloadAddress).isExecutable(), "MAINNET PAYLOAD IS NOT EXECUTABLE");

        bytes32 bytecodeHash = payloadAddress.codehash;

        vm.prank(Ethereum.PAUSE_PROXY);
        IStarGuardLike(Ethereum.SKYBASE_STAR_GUARD).plot({
            addr_ : payloadAddress,
            tag_  : bytecodeHash
        });

        address payload = IStarGuardLike(Ethereum.SKYBASE_STAR_GUARD).exec();

        require(payload == payloadAddress, "FAILED TO EXECUTE PAYLOAD");

        mainnet.spellExecuted = true;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
