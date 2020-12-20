// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

/// @notice Universal Meta Transaction Forwarder Registry
/// Users can record specific forwarder to act on their behalf later
contract ForwarderRegistry {
    using Address for address;
    using ECDSA for bytes32;

    bytes32 internal constant EIP712DOMAIN_NAME = keccak256("ForwarderRegistry");
    bytes32 internal constant APPROVAL_TYPEHASH = keccak256(
        "ApproveForwarder(address forwarder,uint256 nonce,bool approved)"
    );

    //solhint-disable-next-line var-name-mixedcase
    bytes32 internal immutable EIP712DOMAIN_TYPEHASH;

    struct Forwarder {
        uint248 nonce;
        bool approved;
    }
    mapping(address => mapping(address => Forwarder)) internal _forwarders;

    /// @notice emitted for each Forwarder Approval or Disaproval
    event ForwarderApproved(address indexed signer, address indexed forwarder, uint256 nonce, bool approved);

    constructor() {
        EIP712DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    }

    /// @notice The ForwarderRegistry supports every EIP-2771 compliant forwarder.
    function isTrustedForwarder(address) external pure returns (bool) {
        return true;
    }

    /// @notice Forward the meta tx (assuming caller is an approved forwarder)
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function forward(address target, bytes calldata data) external payable {
        address signer = _getSigner();
        require(_forwarders[signer][msg.sender].approved, "NOT_AUTHORIZED_FORWARDER");
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @notice return the current nonce for the signer/forwarder pair
    function getNonce(address signer, address forwarder) external view returns (uint256) {
        return uint256(_forwarders[signer][forwarder].nonce);
    }

    /// @notice return whether a forwarder is approved by a particular signer
    /// @param signer signer who authorized or not the forwarder
    /// @param forwarder meta transaction forwarder contract address
    function isForwarderFor(address signer, address forwarder) external view returns (bool) {
        return forwarder == address(this) || _forwarders[signer][forwarder].approved;
    }

    /// @notice approve forwarder using the forwarder (which is msg.sender)
    /// @param approved whether to approve or disapprove (if previously approved) the forwarder
    /// @param signature signature by signer for approving forwarder
    function approveForwarder(bool approved, bytes calldata signature) external {
        _approveForwarder(_getSigner(), approved, signature);
    }

    /// @notice approve and forward the meta transaction in one call.
    /// @param signature signature by signer for approving forwarder
    /// @param target destination of the call (that will receive the meta transaction)
    /// @param data the content of the call (the signer address will be appended to it)
    function approveAndForward(
        bytes calldata signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _getSigner();
        _approveForwarder(signer, true, signature);
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @notice check approval (but do not record it) and forward the meta transaction in one call.
    /// @param signature signature by signer for approving forwarder
    /// @param target destination of the call (that will receive the meta transaction)
    /// @param data the content of the call (the signer address will be appended to it)
    function checkApprovalAndForward(
        bytes calldata signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _getSigner();
        address forwarder = msg.sender;
        require(
            _isValidSignature(signer, forwarder, uint256(_forwarders[signer][forwarder].nonce), true, signature),
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

    function _getSigner() internal pure returns (address payable result) {
        // from @openzeppelin\contracts\GSN\GSNRecipient.sol
        // We need to read 20 bytes (an address) located at array index msg.data.length - 20. In memory, the array
        // is prefixed with a 32-byte length value, so we first add 32 to get the memory read index. However, doing
        // so would leave the address in the upper 20 bytes of the 32-byte word, which is inconvenient and would
        // require bit shifting. We therefore subtract 12 from the read index so the address lands on the lower 20
        // bytes. This can always be done due to the 32-byte prefix.

        // The final memory read index is msg.data.length - 20 + 32 - 12 = msg.data.length. Using inline assembly is the
        // easiest/most-efficient way to perform this operation.

        // These fields are not accessible from assembly
        bytes memory array = msg.data;
        uint256 index = msg.data.length;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
            result := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
        }
        return result;
    }

    function _encodeMessage(
        address forwarder,
        uint256 nonce,
        bool approved
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    _DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(APPROVAL_TYPEHASH, forwarder, nonce, approved))
                )
            );
    }

    function _isValidSignature(
        address signer,
        address forwarder,
        uint256 nonce,
        bool approved,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 digest = _encodeMessage(forwarder, nonce, approved);
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

        require(_isValidSignature(signer, forwarder, nonce, approved, signature), "SIGNATURE_INVALID");

        forwarderData.approved = approved;
        forwarderData.nonce = uint248(nonce + 1);
        emit ForwarderApproved(signer, forwarder, nonce, approved);
    }
}
