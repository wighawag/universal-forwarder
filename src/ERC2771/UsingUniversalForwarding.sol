// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./UsingMsgSender.sol";
import "./IERC2771.sol";

interface Registry {
    function isForwarderFor(address, address) external view returns (bool);
}

abstract contract UsingUniversalForwarding is UsingMsgSender, IERC2771 {
    Registry internal immutable _registry;
    address internal immutable _universal;

    constructor(Registry registry, address universal) {
        _universal = universal;
        _registry = registry;
    }

    function isTrustedForwarder(address forwarder) external view override returns (bool) {
        return forwarder == _universal || forwarder == address(_registry);
    }

    function _msgSender() internal view override returns (address payable) {
        address payable msgSender = msg.sender;
        address payable sender = super._msgSender();
        if (msgSender == address(_registry) || msgSender == _universal) {
            // if forwarder use appended data
            return sender;
        }

        if (sender == address(0)) {
            // no appended data => use msg.sender
            return msgSender;
        }

        // if appended address non-zero, check if the msg.sender has been registered
        if (_registry.isForwarderFor(sender, msgSender)) {
            return sender;
        } else {
            return msgSender;
        }
    }
}
