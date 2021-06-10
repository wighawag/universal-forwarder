// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./IERC2771.sol";
import "./UsingAppendedCallDataAsSender.sol";

abstract contract UsingSpecificForwarder is UsingAppendedCallDataAsSender, IERC2771 {
    address internal immutable _forwarder;

    constructor(address forwarder) {
        _forwarder = forwarder;
    }

    function isTrustedForwarder(address forwarder) external view override returns (bool) {
        return forwarder == _forwarder;
    }

    function _msgSender() internal view returns (address payable result) {
        if (msg.sender == _forwarder) {
            address payable sender = _appendedDataAsSender();
            if (sender != address(0)) {
                return sender;
            }
        }
        return msg.sender;
    }
}
