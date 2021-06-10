// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../solc_0.7/ERC2771/UsingUniversalForwarding.sol";

contract TestUniversalForwardingReceiver is UsingUniversalForwarding {
    mapping(address => uint256) internal _d;

    event Test(address from, string name);

    // solhint-disable-next-line no-empty-blocks
    constructor(IForwarderRegistry forwarderRegistry, address universalForwarder)
        UsingUniversalForwarding(forwarderRegistry, universalForwarder)
    {}

    function doSomething(address from, string calldata name) external payable {
        require(_msgSender() == from, "NOT_AUTHORIZED");
        emit Test(from, name);
    }

    function test(uint256 d) external {
        address sender = _msgSender();
        _d[sender] = d;
    }

    function getData(address who) external view returns (uint256) {
        return _d[who];
    }
}
