// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./IERC2771.sol";
import "./UsingMsgSender.sol";

abstract contract ERC2771 is UsingMsgSender, IERC2771 {
    address internal immutable _forwarder;

    constructor(address forwarder) {
        _forwarder = forwarder;
    }

    function isTrustedForwarder(address forwarder) external view override returns (bool) {
        return forwarder == _forwarder;
    }
}
