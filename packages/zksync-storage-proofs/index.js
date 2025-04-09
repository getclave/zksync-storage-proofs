const { ethers } = require('ethers');
const { StorageProofProvider } = require('./build/cjs/index');
const { Provider } = require('zksync-ethers');

const l1Provider = new ethers.providers.JsonRpcProvider(
    'https://mainnet.infura.io/v3/2e9d233540364568b0d164b8fe1b31e2',
);
const l2Provider = new Provider('https://mainnet.era.zksync.io');
const diamondAddress = '0x32400084C286CF3E17e7B677ea9583e60a000324';
const verifierAddress = '0x5490D0FE20E9F93a847c1907f7Fd2adF217bF534';
const registryAddress = '0xA0e1Dcb92681E2cD4037b464E99e74D49Ee6ac9f';
const blockOffset = 100;
const registrySlot = 2;
const { Buffer } = require('buffer');

const parseDnsName = (hexName) => {
    const parts = [];

    const sliceBuffer = (buffer, start, end) =>
        Buffer.from(Uint8Array.prototype.slice.call(buffer, start, end));

    let nameBuffer = Buffer.from(hexName.slice(2), 'hex');
    while (nameBuffer[0] != 0x00) {
        const length = nameBuffer[0];
        // Name is buffer slice of [1:length+1]
        const part = sliceBuffer(nameBuffer, 1, length + 1).toString();
        parts.push(part);
        nameBuffer = sliceBuffer(nameBuffer, length + 1);
    }
    return parts;
};

/**
 * Interface of the L1 resolver
 * @dev function resolve(bytes name, bytes data) -> StorageProof
 * @def function resolveFallback(bytes calldata key) -> (bytes memory result, uint64 expires, bytes memory sig)
 */
const OFFCHAIN_RESOLVER_INTERFACE = new ethers.utils.Interface([
    {
        inputs: [
            {
                internalType: 'bytes',
                name: 'name',
                type: 'bytes',
            },
            {
                internalType: 'bytes',
                name: 'data',
                type: 'bytes',
            },
        ],
        name: 'resolve',
        outputs: [
            {
                components: [
                    {
                        components: [
                            {
                                internalType: 'uint64',
                                name: 'batchNumber',
                                type: 'uint64',
                            },
                            {
                                internalType: 'uint64',
                                name: 'indexRepeatedStorageChanges',
                                type: 'uint64',
                            },
                            {
                                internalType: 'uint256',
                                name: 'numberOfLayer1Txs',
                                type: 'uint256',
                            },
                            {
                                internalType: 'bytes32',
                                name: 'priorityOperationsHash',
                                type: 'bytes32',
                            },
                            {
                                internalType: 'bytes32',
                                name: 'l2LogsTreeRoot',
                                type: 'bytes32',
                            },
                            {
                                internalType: 'uint256',
                                name: 'timestamp',
                                type: 'uint256',
                            },
                            {
                                internalType: 'bytes32',
                                name: 'commitment',
                                type: 'bytes32',
                            },
                        ],
                        internalType: 'struct BatchMetadata',
                        name: 'metadata',
                        type: 'tuple',
                    },
                    {
                        internalType: 'address',
                        name: 'account',
                        type: 'address',
                    },
                    {
                        internalType: 'uint256',
                        name: 'key',
                        type: 'uint256',
                    },
                    {
                        internalType: 'bytes32',
                        name: 'value',
                        type: 'bytes32',
                    },
                    {
                        internalType: 'bytes32[]',
                        name: 'path',
                        type: 'bytes32[]',
                    },
                    {
                        internalType: 'uint64',
                        name: 'index',
                        type: 'uint64',
                    },
                ],
                internalType: 'struct StorageProof',
                name: 'proof',
                type: 'tuple',
            },
            {
                internalType: 'bytes32',
                name: 'fallbackValue',
                type: 'bytes32',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
]);

const provider = new StorageProofProvider(
    l1Provider,
    l2Provider,
    diamondAddress,
    verifierAddress,
    blockOffset,
);

const main = async (callData) => {
    const decodedData = OFFCHAIN_RESOLVER_INTERFACE.decodeFunctionData(
        'resolve',
        callData,
    );
    const name = decodedData.name;
    const parts = parseDnsName(name);

    // ENS name must have at least 3 parts, e.g. 'example.clave.eth'
    if (parts.length < 3) {
        return '0x';
    }
    const [subdomain] = parts;
    const abiCoder = new ethers.utils.AbiCoder();

    // Calculate storage key of the subdomain
    const keccakName = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(subdomain),
    );
    const storageKey = ethers.utils.keccak256(
        abiCoder.encode(['bytes32', 'uint8'], [keccakName, registrySlot]),
    );

    const proof = await provider.getProof(registryAddress, storageKey);

    const storageValue = await l2Provider.getStorageAt(
        registryAddress,
        storageKey,
    );

    console.log(`Storage value retrieved ${storageValue}`);

    // ABI encode proof
    const result = OFFCHAIN_RESOLVER_INTERFACE.encodeFunctionResult('resolve', [
        proof,
        storageValue,
    ]);

    console.log(`Result: ${result}`);
    return result;
};
