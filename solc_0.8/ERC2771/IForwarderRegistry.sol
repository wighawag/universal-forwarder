// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IForwarderRegistry {
	function isApprovedForwarder(address, address) external view returns (bool);
}
