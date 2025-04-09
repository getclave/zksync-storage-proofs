/** Processed batch */
export interface StoredBatchInfo {
    batchNumber: bigint;
    batchHash: string;
    indexRepeatedStorageChanges: bigint;
    numberOfLayer1Txs: bigint;
    priorityOperationsHash: string;
    l2LogsTreeRoot: string;
    timestamp: bigint;
    commitment: string;
}

/** Metadata of the batch passed to the contract */
export type BatchMetadata = Omit<StoredBatchInfo, 'batchHash'>;

/** Struct passed to contract by the sequencer for each batch */
export interface CommitBatchInfo {
    batchNumber: bigint;
    timestamp: bigint;
    indexRepeatedStorageChanges: bigint;
    newStateRoot: string;
    numberOfLayer1Txs: bigint;
    priorityOperationsHash: string;
    bootloaderHeapInitialContentsHash: string;
    eventsQueueStateHash: string;
    systemLogs: string;
    totalL2ToL1Pubdata: Uint8Array;
}

/** Proof returned by zkSync RPC */
export type RpcProof = {
    account: string;
    key: string;
    path: Array<string>;
    value: string;
    index: number;
};

export type StorageProofBatch = {
    metadata: BatchMetadata;
    proofs: RpcProof[];
};

export type StorageProof = RpcProof & {
    metadata: BatchMetadata;
};
