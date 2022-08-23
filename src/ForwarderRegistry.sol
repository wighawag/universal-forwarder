// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../_lib/openzeppelin/contracts/utils/Address.sol";
import "../_lib/openzeppelin/contracts/cryptography/ECDSA.sol";
import "./solc_0.7/ERC2771/IERC2771.sol";
import "./solc_0.7/ERC2771/UsingAppendedCallData.sol";

interface ERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}

/// @notice Universal Meta Transaction Forwarder Registry.
/// Users can record specific forwarder that will be allowed to forward meta transactions on their behalf.
contract ForwarderRegistry is UsingAppendedCallData, IERC2771 {
    using Address for address;
    using ECDSA for bytes32;

    bytes4 internal constant ERC1271_MAGICVALUE = 0x1626ba7e;

    bytes32 internal constant EIP712_DOMAIN_NAME = keccak256("ForwarderRegistry");
    bytes32 internal constant APPROVAL_TYPEHASH =
        keccak256("ApproveForwarder(address forwarder,bool approved,uint256 nonce)");

    uint256 private immutable _deploymentChainId;
    bytes32 private immutable _deploymentDomainSeparator;

    struct Forwarder {
        uint248 nonce;
        bool approved;
    }
    mapping(address => mapping(address => Forwarder)) internal _forwarders;

    /// @notice emitted for each Forwarder Approval or Disaproval.
    event ForwarderApproved(address indexed signer, address indexed forwarder, bool approved, uint256 nonce);

    constructor() {
        uint256 chainId;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
        _deploymentChainId = chainId;
        _deploymentDomainSeparator = _calculateDomainSeparator(chainId);
    }

    /// @notice The ForwarderRegistry supports every EIP-2771 compliant forwarder.
    function isTrustedForwarder(address) external pure override returns (bool) {
        return true;
    }

    /// @notice Forward the meta tx (assuming caller has been approved by the signer as forwarder).
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function forward(address target, bytes calldata data) external payable {
        address signer = _lastAppendedDataAsSender();
        require(_forwarders[signer][msg.sender].approved, "NOT_AUTHORIZED_FORWARDER");
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @notice return the current nonce for the signer/forwarder pair.
    /// @param signer signer who authorize/dauthorize forwarders
    /// @param forwarder meta transaction forwarder contract address.
    function getNonce(address signer, address forwarder) external view returns (uint256) {
        return uint256(_forwarders[signer][forwarder].nonce);
    }

    /// @notice return whether a forwarder is approved by a particular signer.
    /// @param signer signer who authorized or not the forwarder.
    /// @param forwarder meta transaction forwarder contract address.
    function isApprovedForwarder(address signer, address forwarder) external view returns (bool) {
        return _forwarders[signer][forwarder].approved;
    }

    /// @notice approve a forwarder using EIP-2771 (msg.sender is a forwarder and signer is encoded in the appended data).
    /// @param forwarderToChangeApproval address of the forwarder to approve
    /// @param approved whether to approve or disapprove (if previously approved) the forwarder.
    /// @param signature signature by signer for approving forwarder.
    /// @param isEIP1271Signature true if the signer is a contract that require authorization via EIP-1271
    function approveForwarder(
        address forwarderToChangeApproval,
        bool approved,
        bytes calldata signature,
        bool isEIP1271Signature
    ) external {
        _approveForwarder(
            _lastAppendedDataAsSender(),
            forwarderToChangeApproval,
            approved,
            signature,
            isEIP1271Signature
        );
    }

    /// @notice approve and forward the meta transaction in one call.
    /// @param signature signature by signer for approving forwarder.
    /// @param isEIP1271Signature true if the signer is a contract that require authorization via EIP-1271
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function approveAndForward(
        bytes calldata signature,
        bool isEIP1271Signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _lastAppendedDataAsSender();
        _approveForwarder(signer, msg.sender, true, signature, isEIP1271Signature);
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @notice check approval (but do not record it) and forward the meta transaction in one call.
    /// @param signature signature by signer for approving forwarder.
    /// @param isEIP1271Signature true if the signer is a contract that require authorization via EIP-1271
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function checkApprovalAndForward(
        bytes calldata signature,
        bool isEIP1271Signature,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _lastAppendedDataAsSender();
        address forwarder = msg.sender;
        _requireValidSignature(
            signer,
            forwarder,
            true,
            uint256(_forwarders[signer][forwarder].nonce),
            signature,
            isEIP1271Signature
        );
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @dev Return the DOMAIN_SEPARATOR.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR();
    }

    // -------------------------------------------------------- INTERNAL --------------------------------------------------------------------

    /// @dev Return the DOMAIN_SEPARATOR.
    function _DOMAIN_SEPARATOR() internal view returns (bytes32) {
        uint256 chainId;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }

        // in case a fork happen, to support the chain that had to change its chainId, we compue the domain operator
        return chainId == _deploymentChainId ? _deploymentDomainSeparator : _calculateDomainSeparator(chainId);
    }

    /// @dev Calculate the DOMAIN_SEPARATOR.
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                    EIP712_DOMAIN_NAME,
                    chainId,
                    address(this)
                )
            );
    }

    function _encodeMessage(
        address forwarder,
        bool approved,
        uint256 nonce
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR(),
                keccak256(abi.encode(APPROVAL_TYPEHASH, forwarder, approved, nonce))
            );
    }

    function _requireValidSignature(
        address signer,
        address forwarder,
        bool approved,
        uint256 nonce,
        bytes memory signature,
        bool isEIP1271Signature
    ) internal view {
        bytes memory dataToHash = _encodeMessage(forwarder, approved, nonce);
        if (isEIP1271Signature) {
            require(
                ERC1271(signer).isValidSignature(keccak256(dataToHash), signature) == ERC1271_MAGICVALUE,
                "SIGNATURE_1271_INVALID"
            );
        } else {
            address actualSigner = keccak256(dataToHash).recover(signature);
            require(signer == actualSigner, "SIGNATURE_WRONG_SIGNER");
        }
    }

    function _approveForwarder(
        address signer,
        address forwarderToChangeApproval,
        bool approved,
        bytes memory signature,
        bool isEIP1271Signature
    ) internal {
        Forwarder storage forwarderData = _forwarders[signer][forwarderToChangeApproval];
        uint256 nonce = uint256(forwarderData.nonce);

        _requireValidSignature(signer, forwarderToChangeApproval, approved, nonce, signature, isEIP1271Signature);

        forwarderData.approved = approved;
        forwarderData.nonce = uint248(nonce + 1);
        emit ForwarderApproved(signer, forwarderToChangeApproval, approved, nonce);
    }
}
