// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./ERC2771/IERC2771.sol";
import "./ERC2771/MsgSender.sol";

/// @notice Universal Meta Transaction Forwarder
/// It does not perform any extra logic apart from checing if the caller (metatx forwarder) has been approved via signature.
/// Note that forwarder approval are forever. This is to remove the need to read storage. Signature need to be given each time.
/// The overhead (on top of the specific metatx forwarder) is thus just an extra contract load and call + signature check.
contract NoStorageUniversalForwarder is MsgSender, IERC2771 {
    using Address for address;
    using ECDSA for bytes32;

    bytes32 internal constant EIP712DOMAIN_NAME = keccak256("UniversalForwarder");
    bytes32 internal constant APPROVAL_TYPEHASH = keccak256("ApproveForwarder(address forwarder)");

    //solhint-disable-next-line var-name-mixedcase
    bytes32 internal immutable EIP712DOMAIN_TYPEHASH;

    constructor() {
        EIP712DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    }

    /// @notice The UniversalForwarder supports every EIP-2771 compliant forwarder.
    function isTrustedForwarder(address) external pure override returns (bool) {
        return true;
    }

    /// @notice Forward the meta transaction by first checking signature if forwarder is approved : no storage involved, approving is forever.
    /// @param signature signature by signer for approving forwarder.
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function forward(
        bytes calldata signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _msgSender();
        require(_isValidSignature(signer, msg.sender, signature), "SIGNATURE_INVALID");
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

    function _encodeMessage(address forwarder) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR(), keccak256(abi.encode(APPROVAL_TYPEHASH, forwarder)))
            );
    }

    function _isValidSignature(
        address signer,
        address forwarder,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 digest = _encodeMessage(forwarder);
        return signer == digest.recover(signature);
    }
}
