import { Interface } from 'ethers';

/** Interface of the Diamond Contract */
export const ZKSYNC_DIAMOND_INTERFACE = new Interface([
    `function commitBatchesSharedBridge(
        uint256 _chainId,
        uint256 _processBatchFrom,
        uint256 _processBatchTo,
        bytes calldata
  )`,
    `function l2LogsRootHash(uint256 _batchNumber) external view returns (bytes32)`,
    `function storedBatchHash(uint256) public view returns (bytes32)`,
    `event BlockCommit(uint256 indexed batchNumber, bytes32 indexed batchHash, bytes32 indexed commitment)`,
]);

export const STORAGE_VERIFIER_INTERFACE = new Interface([
    `function verify(
        ( (uint64 batchNumber,
           uint64 indexRepeatedStorageChanges,
           uint256 numberOfLayer1Txs,
           bytes32 priorityOperationsHash,
           bytes32 l2LogsTreeRoot,
           uint256 timestamp,
           bytes32 commitment ) metadata,
          address account,
          uint256 key,
          bytes32 value,
          bytes32[] path,
          uint64 index ) proof
    ) view returns (bool)`,
]);

export const STORED_BATCH_INFO_ABI_STRING =
    'tuple(uint64 batchNumber, bytes32 batchHash, uint64 indexRepeatedStorageChanges, uint256 numberOfLayer1Txs, bytes32 priorityOperationsHash, bytes32 l2LogsTreeRoot, uint256 timestamp, bytes32 commitment)';
export const COMMIT_BATCH_INFO_ABI_STRING =
    'tuple(uint64 batchNumber, uint64 timestamp, uint64 indexRepeatedStorageChanges, bytes32 newStateRoot, uint256 numberOfLayer1Txs, bytes32 priorityOperationsHash, bytes32 bootloaderHeapInitialContentsHash, bytes32 eventsQueueStateHash, bytes systemLogs, bytes operatorDAInput)';
