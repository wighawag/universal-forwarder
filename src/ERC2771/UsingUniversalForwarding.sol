// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./UsingMsgSender.sol";
import "./IERC2771.sol";
import "./IForwarderRegistry.sol";

abstract contract UsingUniversalForwarding is UsingMsgSender, IERC2771 {
    IForwarderRegistry internal immutable _forwarderRegistry;
    address internal immutable _universalForwarder;

    constructor(IForwarderRegistry forwarderRegistry, address universalForwarder) {
        _universalForwarder = universalForwarder;
        _forwarderRegistry = forwarderRegistry;
    }

    function isTrustedForwarder(address forwarder) external view override returns (bool) {
        return forwarder == _universalForwarder || forwarder == address(_forwarderRegistry);
    }

    function _msgSender() internal view override returns (address payable) {
        address payable msgSender = msg.sender;
        address payable sender = super._msgSender();
        if (msgSender == address(_forwarderRegistry) || msgSender == _universalForwarder) {
            // if forwarder use appended data
            return sender;
        }

        if (sender == address(0)) {
            // no appended data => use msg.sender
            return msgSender;
        }

        // if appended address non-zero, check if the msg.sender has been registered
        if (_forwarderRegistry.isForwarderFor(sender, msgSender)) {
            return sender;
        } else {
            return msgSender;
        }
    }
}
