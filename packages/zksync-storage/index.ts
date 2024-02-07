import {
  Provider as L1Provider,
  Interface,
  Contract,
  keccak256,
  AbiCoder,
} from "ethers";
import { Provider as L2Provider } from "zksync-ethers";
import { BatchMetadata, CommitBatchInfo, StorageProof, StoredBatchInfo } from "./types";
import { JsonRpcProvider } from "ethers";

const ZKSYNC_DIAMOND_ADDRESS = "0x32400084C286CF3E17e7B677ea9583e60a000324";
const ZKSYNC_DIAMOND_INTERFACE = new Interface([
  `function commitBatches(
        (uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32) lastCommittedBatchData,
        (uint64,uint64,uint64,bytes32,uint256,bytes32,bytes32,bytes32,bytes,bytes)[] newBatchesData
    )`,
  "function l2LogsRootHash(uint256 _batchNumber) external view returns (bytes32)",
  "event BlockCommit(uint256 indexed batchNumber, bytes32 indexed batchHash, bytes32 indexed commitment)",
  "function storedBatchHash(uint256) public view returns (bytes32)",
]);

/** Omits batch hash from stored batch info */
const formatStoredBatchInfo = (batchInfo: StoredBatchInfo): BatchMetadata => {
  const { batchHash, ...metadata } = batchInfo;
  return metadata;
}

/** Hashes StoredBatchInfo struct in the same way Solidity code does */
const hashStoredBatchInfo = (batchInfo: StoredBatchInfo): string => {
  return keccak256(
    AbiCoder.defaultAbiCoder().encode(
      [
        "uint64",
        "bytes32",
        "uint64",
        "uint256",
        "bytes32",
        "bytes32",
        "uint256",
        "bytes32",
      ],
      [
        batchInfo.batchNumber,
        batchInfo.batchHash,
        batchInfo.indexRepeatedStorageChanges,
        batchInfo.numberOfLayer1Txs,
        batchInfo.priorityOperationsHash,
        batchInfo.l2LogsTreeRoot,
        batchInfo.timestamp,
        batchInfo.commitment,
      ]
    )
  );
}

/**
 * Returns the stored batch info for the given batch number.
 * Returns null if the batch is not stored.
 * @param l1Provider
 * @param l2Provider
 * @param batchNumber
 */
export async function getStoredBatchInfo(
  l1Provider: L1Provider,
  l2Provider: L2Provider,
  batchNumber: number
): Promise<StoredBatchInfo> {
  const { commitTxHash, proveTxHash } = await l2Provider.getL1BatchDetails(
    batchNumber
  );

  // If batch is not committed or proved, return null
  if (commitTxHash == undefined) {
    throw new Error(`Batch ${batchNumber} is not committed`);
  } else if (proveTxHash == undefined) {
    throw new Error(`Batch ${batchNumber} is not proved`);
  }

  // Parse commit calldata from commit transaction
  const { commitBatchInfo, commitment } = await parseCommitTransaction(
    l1Provider,
    commitTxHash,
    batchNumber
  );
  const l2LogsTreeRoot = await getL2RootsHash(l1Provider, batchNumber);

  const storedBatchInfo: StoredBatchInfo = {
    batchNumber: commitBatchInfo.batchNumber,
    batchHash: commitBatchInfo.newStateRoot,
    indexRepeatedStorageChanges: commitBatchInfo.indexRepeatedStorageChanges,
    numberOfLayer1Txs: commitBatchInfo.numberOfLayer1Txs,
    priorityOperationsHash: commitBatchInfo.priorityOperationsHash,
    l2LogsTreeRoot,
    timestamp: commitBatchInfo.timestamp,
    commitment,
  };
  return storedBatchInfo;
}

async function getL2RootsHash(
  l1Provider: L1Provider,
  batchNumber: number
): Promise<string> {
  const contract = new Contract(
    ZKSYNC_DIAMOND_ADDRESS,
    ZKSYNC_DIAMOND_INTERFACE,
    l1Provider
  );
  const l2RootsHash = await contract.l2LogsRootHash(batchNumber);
  return String(l2RootsHash);
}

async function parseCommitTransaction(
  l1Provider: L1Provider,
  txHash: string,
  batchNumber: number
): Promise<{ commitBatchInfo: CommitBatchInfo; commitment: string }> {
  const transactionData = await l1Provider.getTransaction(txHash);
  const [, newBatch] = ZKSYNC_DIAMOND_INTERFACE.decodeFunctionData(
    "commitBatches",
    transactionData!.data
  );

  // Find the batch with matching number
  const batch = newBatch.find((batch: any) => {
    return batch[0] === BigInt(batchNumber);
  });
  if (batch == undefined) {
    throw new Error(`Batch ${batchNumber} not found in calldata`);
  }

  const commitBatchInfo: CommitBatchInfo = {
    batchNumber: batch[0],
    timestamp: batch[1],
    indexRepeatedStorageChanges: batch[2],
    newStateRoot: batch[3],
    numberOfLayer1Txs: batch[4],
    priorityOperationsHash: batch[5],
    bootloaderHeapInitialContentsHash: batch[6],
    eventsQueueStateHash: batch[7],
    systemLogs: batch[8],
    totalL2ToL1Pubdata: batch[9],
  };

  const receipt = await l1Provider.getTransactionReceipt(txHash);
  if (receipt == undefined) {
    throw new Error(`Receipt for tx ${txHash} not found`);
  }

  // Parse event logs of the transaction to find commitment
  const blockCommitFilter = ZKSYNC_DIAMOND_INTERFACE.encodeFilterTopics(
    "BlockCommit",
    [batchNumber]
  );
  const commitLog = receipt.logs.find(
    (log) =>
      log.address === ZKSYNC_DIAMOND_ADDRESS &&
      blockCommitFilter.every((topic, i) => topic === log.topics[i])
  );
  if (commitLog == undefined) {
    throw new Error(`Commit log for batch ${batchNumber} not found`);
  }
  const { commitment } = ZKSYNC_DIAMOND_INTERFACE.decodeEventLog(
    "BlockCommit",
    commitLog.data,
    commitLog.topics
  );

  return { commitBatchInfo, commitment };
}

async function getProofFromL2(
  l2Provider: L2Provider,
  account: string,
  storageKeys: Array<string>,
  batchNumber: number
): Promise<Array<StorageProof>> {
  try {
    // Account proofs don't exist in zkSync, so we're only using storage proofs
    const { storageProof } = await l2Provider.send("zks_getProof", [
      account,
      storageKeys,
      batchNumber,
    ]);
    return { ...storageProof, account };
  } catch (e) {
    throw new Error(`Failed to get proof from L2 provider, ${e}`);
  }
}

async function getProofs(
  l1Provider: L1Provider,
  l2Provider: L2Provider,
  address: string,
  storageKeys: Array<string>,
  batchNumber?: number
): Promise<{
  batchMetadata: Omit<StoredBatchInfo, "batchHash">;
  proofs: Array<StorageProof>;
}> {
  // If batch number is not provided, get the latest batch number
  if (batchNumber === undefined) {
    console.log(await l2Provider.getL1BatchNumber());
    batchNumber = (await l2Provider.getL1BatchNumber()) - 2000;
  }
  console.log(`Getting proofs for batch #${batchNumber}`);

  const proofs = await getProofFromL2(
    l2Provider,
    address,
    storageKeys,
    batchNumber
  );

  const batchMetadata = await getStoredBatchInfo(
    l1Provider,
    l2Provider,
    batchNumber
  ).then(formatStoredBatchInfo);

  return { batchMetadata, proofs };
}

async function main() {
  const batchNumber = process.argv[2] ? parseInt(process.argv[2]) : undefined;
  const l1Provider = new JsonRpcProvider(process.env.ETHEREUM_RPC_URL);
  const l2Provider = new L2Provider(process.env.ZKSYNC_RPC_URL);
  const proof = await getProofs(
    l1Provider,
    l2Provider,
    "0x0000000000000000000000000000000000008003",
    ["0x8b65c0cf1012ea9f393197eb24619fd814379b298b238285649e14f936a5eb12"],
    batchNumber
  );
  console.log(proof);
}

main();
