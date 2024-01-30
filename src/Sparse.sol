// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Blake2s} from "./Blake2s.sol";
import "forge-std/console.sol";

// Type conversion between Rust implementation and Solidity implementation
// H32          :           bytes32
// U256         :           uint256
// Key          :           uint256
// ValueHash    :           bytes32

/// @title Sparse Tree Entry
/// @member value The value of the entry
/// @member leafIndex The index of the leaf in the tree
struct TreeEntry {
    uint256 key;
    bytes32 value;
    uint64 leafIndex;
}

uint256 constant KEY_SIZE = 32;
uint256 constant TREE_DEPTH = KEY_SIZE * 8;

contract Sparse {
    mapping(uint256 => bytes32) public emptyTreeHashes_;

    constructor() {
        emptyTreeHashes_[0] = Blake2s.toBytes32(emptyLeaf());

        bytes32 lastHash = emptyTreeHashes_[0];
        for (uint256 i = 1; i < TREE_DEPTH + 1; i++) {
            lastHash = Blake2s.toBytes32(abi.encodePacked(lastHash, lastHash));
            emptyTreeHashes_[i] = lastHash;
        }
    }

    /// @notice Folds the merkle tree
    function foldMerklePath(
        bytes32[] memory path,
        TreeEntry memory entry
    ) public view returns (bytes32) {
        bytes32 hashValue = hashLeaf(entry.leafIndex, entry.value);
        bytes32[] memory full_path = extendMerklePath(path);
        for (uint256 depth = 0; depth < full_path.length; depth++) {
            bytes32 adjacentHash = full_path[depth];
            if (bit(entry.key, depth)) {
                hashValue = hashBranch(adjacentHash, hashValue);
            } else {
                hashValue = hashBranch(hashValue, adjacentHash);
            }
        }
        return hashValue;
    }

    function hashBranch(
        bytes32 left,
        bytes32 right
    ) public pure returns (bytes32) {
        bytes32 res = compress(left, right);
        return res;
    }

    function compress(
        bytes32 left,
        bytes32 right
    ) public pure returns (bytes32 result) {
        uint32[8] memory digest = Blake2s.toDigest(abi.encodePacked(left), abi.encodePacked(right));

        // Loop through each 32-bit word in the digest array and construct a single bytes32 result.
        // This is done by shifting each 32-bit word to its correct position in the 256-bit result
        // and combining them using the bitwise OR operation.
        for (uint i = 0; i < digest.length; i++) {
            result = bytes32(
                uint256(result) | (uint256(digest[i]) << (256 - ((i + 1) * 32)))
            );
        }
    }


    function emptyLeaf() public pure returns (bytes memory) {
        return new bytes(40);
    }

    /// @notice Hashes an individual leaf
    function hashLeaf(
        uint64 leafIndex,
        bytes32 value
    ) public pure returns (bytes32) {
        bytes memory input = new bytes(40);
        assembly {
            // Store leafIndex at first 8 bytes
            mstore(add(input, 0x20), shl(192, leafIndex))
            // Store value at last 32 bytes
            mstore(add(input, 0x28), value)
        }
        return Blake2s.toBytes32(input);
    }

    function extendMerklePath(
        bytes32[] memory path
    ) public view returns (bytes32[] memory) {
        uint256 emptyHashCount = TREE_DEPTH - path.length;
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < emptyHashCount; i++) {
            hashes[i] = emptyTreeHashes_[i];
        }
        for (uint256 i = 0; i < path.length; i++) {
            hashes[emptyHashCount + i] = path[i];
        }
        return hashes;
    }

    function bit(
        uint256 value,
        uint256 bitOffset
    ) public pure returns (bool) {
        return (value >> bitOffset) & 1 == 1;
    }
}
