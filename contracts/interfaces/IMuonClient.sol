// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMuonClient {
    /**
     * @notice Data structure representing a Muon Schnorr signature.
     *
     * @param signature The Schnorr signature scalar packed into a uint256.
     * @param owner     The address of the signer (public key owner) that produced the signature.
     * @param nonce     The nonce associated with the Schnorr signature, encoded as an address.
     */
    struct SchnorrSign {
        uint256 signature;
        address owner;
        address nonce;
    }

    /**
     * @dev Represents a secp256k1 public key in compressed form.
     * @notice Stored as the x-coordinate and the parity (least significant bit) of the y-coordinate.
     * @param x The x-coordinate of the public key on the curve (uint256).
     * @param parity The parity (0 or 1) of the y-coordinate used to reconstruct the full point.
     */
    struct PublicKey {
        uint256 x;
        uint8 parity;
    }

    /**
     * @notice Verify a Schnorr signature produced by the Muon network for a given request and payload hash.
     * @param reqId   The Muon request identifier associated with this signature.
     * @param hash    The 32-byte message hash encoded as a uint256 that was signed.
     * @param signature The Schnorr signature structure produced by Muon.
     * @param pubKey  The Muon public key parameters used to verify the signature.
     * @return valid  True if the signature is valid for `hash` under `pubKey` for the given `reqId`, otherwise false.
     */
    function muonVerify(
        bytes calldata reqId,
        uint256 hash,
        SchnorrSign memory signature,
        PublicKey memory pubKey
    ) external returns (bool);
}
