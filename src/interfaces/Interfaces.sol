// SPDX-License-Identifier: AGPL-3.0

pragma solidity >=0.7.5 <0.9.0;

/// @dev Forked from https://github.com/sparkdotfi/spark-spells/blob/95452a6c53b38df4526082481b19ba05a9cb43b3/src/interfaces/Interfaces.sol

interface IStarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
    function exec() external returns (address addr);
}
