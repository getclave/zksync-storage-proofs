// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SparseMerkleTree, TreeEntry } from "./SparseMerkleTree.sol";

/// @notice Interface for the zkSync's contract
interface IZkSyncDiamond {
    /// @notice Returns the hash of the stored batch
    function storedBatchHash(uint256) external view returns (bytes32);
}

/// `StoredBatchInfo` struct declared in https://github.com/matter-labs/era-contracts/blob/main/l1-contracts/contracts/zksync/interfaces/IExecutor.sol
/// @dev batchHash is omitted because it will be calculated from the proof
///
/// @notice Rollup batch stored data
/// @param batchNumber Rollup batch number
/// @param indexRepeatedStorageChanges The serial number of the shortcut index that's used as a unique identifier for storage keys that were used twice or more
/// @param numberOfLayer1Txs Number of priority operations to be processed
/// @param priorityOperationsHash Hash of all priority operations from this batch
/// @param l2LogsTreeRoot Root hash of tree that contains L2 -> L1 messages from this batch
/// @param timestamp Rollup batch timestamp, have the same format as Ethereum batch constant
/// @param commitment Verified input for the zkSync circuit
struct BatchMetadata {
    uint64 batchNumber;
    uint64 indexRepeatedStorageChanges;
    uint256 numberOfLayer1Txs;
    bytes32 priorityOperationsHash;
    bytes32 l2LogsTreeRoot;
    uint256 timestamp;
    bytes32 commitment;
}

/// @notice Storage proof that proves a storage key-value pair is included in the batch
struct StorageProof {
    BatchMetadata metadata;
    address account;
    bytes32[] path;
    uint256 key;
    bytes32 value;
    uint64 index;
}

contract StorageProofVerifier {
    IZkSyncDiamond immutable public zksyncDiamondAddress;
    SparseMerkleTree public smt;

    constructor(IZkSyncDiamond _zksyncDiamondAddress, SparseMerkleTree _smt) {
        zksyncDiamondAddress = _zksyncDiamondAddress;
        smt = _smt;
    }

    /// @notice Verifies the storage proof
    function verify(StorageProof calldata _proof) external view returns (bool valid) {
        bytes32 computedRootHash = smt.getRootHash(
            _proof.path, 
            TreeEntry({
                key: _proof.key,
                value: _proof.value,
                leafIndex: _proof.index
            }), 
            _proof.account
        );
        bytes32 storedRootHash = zksyncDiamondAddress.storedBatchHash(_proof.metadata.batchNumber);
        valid = computedRootHash == storedRootHash;
    }
}