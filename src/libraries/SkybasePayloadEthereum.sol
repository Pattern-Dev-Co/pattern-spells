// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

/**
 * @dev Base smart contract for Skybase Ethereum spells.
 * @author Soter Labs
 */
abstract contract SkybasePayloadEthereum {

    function execute() external {
        _execute();
    }

    /**
     * @notice Checks if the star payload is executable in the current block
     * @dev Required, useful for implementing "earliest launch date" or "office hours" strategy
     * @return result The result of the check (true = executable, false = not)
     */
    function isExecutable() external pure returns (bool result) {
        result = true;
    }

    function _execute() internal virtual;
}
