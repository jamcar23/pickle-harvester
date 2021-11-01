// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

/// @notice interface to wrap the different types of
/// chefs that pickle uses on different networks.
interface IChef {
    function deposit(uint256 _pid, uint256 _amount, address _user) external;
    function harvest(uint256 _pid, address _to) external;
    function pendingPickle(uint256 _pid, address _user) external view returns (uint256 pending);
}