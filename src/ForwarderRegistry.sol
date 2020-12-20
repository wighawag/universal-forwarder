// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./ERC2771/IERC2771.sol";
import "./ERC2771/UsingMsgSender.sol";

/// @notice Universal Meta Transaction Forwarder Registry.
/// Users can record specific forwarder to act on their behalf later.
contract ForwarderRegistry is UsingMsgSender, IERC2771 {
    using Address for address;
    using ECDSA for bytes32;

    bytes32 internal constant EIP712DOMAIN_NAME = keccak256("ForwarderRegistry");
    bytes32 internal constant APPROVAL_TYPEHASH = keccak256(
        "ApproveForwarder(address forwarder,bool approved,uint256 nonce)"
    );

    //solhint-disable-next-line var-name-mixedcase
    bytes32 internal immutable EIP712DOMAIN_TYPEHASH;

    struct Forwarder {
        uint248 nonce;
        bool approved;
    }
    mapping(address => mapping(address => Forwarder)) internal _forwarders;

    /// @notice emitted for each Forwarder Approval or Disaproval.
    event ForwarderApproved(address indexed signer, address indexed forwarder, bool approved, uint256 nonce);

    constructor() {
        EIP712DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    }

    /// @notice The ForwarderRegistry supports every EIP-2771 compliant forwarder.
    function isTrustedForwarder(address) external pure override returns (bool) {
        return true;
    }

    /// @notice Forward the meta tx (assuming caller has been approved by the signer as forwarder).
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function forward(address target, bytes calldata data) external payable {
        address signer = _msgSender();
        require(_forwarders[signer][msg.sender].approved, "NOT_AUTHORIZED_FORWARDER");
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @notice return the current nonce for the signer/forwarder pair.
    function getNonce(address signer, address forwarder) external view returns (uint256) {
        return uint256(_forwarders[signer][forwarder].nonce);
    }

    /// @notice return whether a forwarder is approved by a particular signer.
    /// @param signer signer who authorized or not the forwarder.
    /// @param forwarder meta transaction forwarder contract address.
    function isForwarderFor(address signer, address forwarder) external view returns (bool) {
        return forwarder == address(this) || _forwarders[signer][forwarder].approved;
    }

    /// @notice approve forwarder using the forwarder (which is msg.sender).
    /// @param approved whether to approve or disapprove (if previously approved) the forwarder.
    /// @param signature signature by signer for approving forwarder.
    function approveForwarder(bool approved, bytes calldata signature) external {
        _approveForwarder(_msgSender(), approved, signature);
    }

    /// @notice approve and forward the meta transaction in one call.
    /// @param signature signature by signer for approving forwarder.
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function approveAndForward(
        bytes calldata signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _msgSender();
        _approveForwarder(signer, true, signature);
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @notice check approval (but do not record it) and forward the meta transaction in one call.
    /// @param signature signature by signer for approving forwarder.
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function checkApprovalAndForward(
        bytes calldata signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _msgSender();
        address forwarder = msg.sender;
        require(
            _isValidSignature(signer, forwarder, true, uint256(_forwarders[signer][forwarder].nonce), signature),
            "SIGNATURE_INVALID"
        );
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    // -------------------------------------------------------- INTERNAL --------------------------------------------------------------------

    /// @notice return the domain separator to compute allowing to check if the signature would be valid.
    function _DOMAIN_SEPARATOR() internal view returns (bytes32) {
        // use dynamic DOMAIN_SEPARATOR to ensure the contract remains valid on all forks.
        uint256 chainId;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encode(EIP712DOMAIN_TYPEHASH, EIP712DOMAIN_NAME, chainId));
    }

    function _encodeMessage(
        address forwarder,
        bool approved,
        uint256 nonce
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    _DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(APPROVAL_TYPEHASH, forwarder, approved, nonce))
                )
            );
    }

    function _isValidSignature(
        address signer,
        address forwarder,
        bool approved,
        uint256 nonce,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 digest = _encodeMessage(forwarder, approved, nonce);
        return signer == digest.recover(signature);
    }

    function _approveForwarder(
        address signer,
        bool approved,
        bytes memory signature
    ) internal {
        address forwarder = msg.sender;
        Forwarder storage forwarderData = _forwarders[signer][forwarder];
        uint256 nonce = uint256(forwarderData.nonce);

        require(_isValidSignature(signer, forwarder, approved, nonce, signature), "SIGNATURE_INVALID");

        forwarderData.approved = approved;
        forwarderData.nonce = uint248(nonce + 1);
        emit ForwarderApproved(signer, forwarder, approved, nonce);
    }
}
