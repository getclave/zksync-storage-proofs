import {console} from "forge-std/Test.sol";

library UncheckedMath {
    function uncheckedInc(uint256 _number) internal pure returns (uint256) {
        unchecked {
            return _number + 1;
        }
    }

    function uncheckedAdd(uint256 _lhs, uint256 _rhs)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return _lhs + _rhs;
        }
    }
}

library UnsafeBytes {
    function readUint32(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint32 result, uint256 offset)
    {
        assembly {
            offset := add(_start, 4)
            result := mload(add(_bytes, offset))
        }
    }

    function readAddress(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (address result, uint256 offset)
    {
        assembly {
            offset := add(_start, 20)
            result := mload(add(_bytes, offset))
        }
    }

    function readUint256(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint256 result, uint256 offset)
    {
        assembly {
            offset := add(_start, 32)
            result := mload(add(_bytes, offset))
        }
    }

    function readBytes32(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes32 result, uint256 offset)
    {
        assembly {
            offset := add(_start, 32)
            result := mload(add(_bytes, offset))
        }
    }
}

uint256 constant L2_TO_L1_LOG_SERIALIZE_SIZE = 88;

/// @dev Offset used to pull Address From Log. Equal to 4 (bytes for isService)
uint256 constant L2_LOG_ADDRESS_OFFSET = 4;

/// @dev Offset used to pull Key From Log. Equal to 4 (bytes for isService) + 20 (bytes for address)
uint256 constant L2_LOG_KEY_OFFSET = 24;

/// @dev Offset used to pull Value From Log. Equal to 4 (bytes for isService) + 20 (bytes for address) + 32 (bytes for key)
uint256 constant L2_LOG_VALUE_OFFSET = 56;

struct CommitBatchInfo {
    uint64 batchNumber;
    uint64 timestamp;
    uint64 indexRepeatedStorageChanges;
    bytes32 newStateRoot;
    uint256 numberOfLayer1Txs;
    bytes32 priorityOperationsHash;
    bytes32 bootloaderHeapInitialContentsHash;
    bytes32 eventsQueueStateHash;
    bytes systemLogs;
    bytes totalL2ToL1Pubdata;
}

enum SystemLogKey {
    L2_TO_L1_LOGS_TREE_ROOT_KEY,
    TOTAL_L2_TO_L1_PUBDATA_KEY,
    STATE_DIFF_HASH_KEY,
    PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY,
    PREV_BATCH_HASH_KEY,
    CHAINED_PRIORITY_TXN_HASH_KEY,
    NUMBER_OF_LAYER_1_TXS_KEY,
    EXPECTED_SYSTEM_CONTRACT_UPGRADE_TX_HASH_KEY
}

contract Executor {
    using UncheckedMath for uint256;

    /// @dev Check that L2 logs are proper and batch contain all meta information for them
    /// @dev The logs processed here should line up such that only one log for each key from the
    ///      SystemLogKey enum in Constants.sol is processed per new batch.
    /// @dev Data returned from here will be used to form the batch commitment.
    function _processL2Logs(
        CommitBatchInfo calldata _newBatch,
        bytes32 _expectedSystemContractUpgradeTxHash
    )
        public
        view
        returns (
            uint256 numberOfLayer1Txs,
            bytes32 chainedPriorityTxsHash,
            bytes32 previousBatchHash,
            bytes32 stateDiffHash,
            bytes32 l2LogsTreeRoot,
            uint256 packedBatchAndL2BlockTimestamp
        )
    {
        // Copy L2 to L1 logs into memory.
        bytes memory emittedL2Logs = _newBatch.systemLogs;

        // Used as bitmap to set/check log processing happens exactly once.
        // See SystemLogKey enum in Constants.sol for ordering.
        uint256 processedLogs;

        bytes32 providedL2ToL1PubdataHash = keccak256(
            _newBatch.totalL2ToL1Pubdata
        );

        console.logBytes(emittedL2Logs);

        // linear traversal of the logs
        for (
            uint256 i = 0;
            i < emittedL2Logs.length;
            i = i.uncheckedAdd(L2_TO_L1_LOG_SERIALIZE_SIZE)
        ) {
            // Extract the values to be compared to/used such as the log sender, key, and value
            (address logSender, ) = UnsafeBytes.readAddress(
                emittedL2Logs,
                i + L2_LOG_ADDRESS_OFFSET
            );
            (uint256 logKey, ) = UnsafeBytes.readUint256(
                emittedL2Logs,
                i + L2_LOG_KEY_OFFSET
            );
            (bytes32 logValue, ) = UnsafeBytes.readBytes32(
                emittedL2Logs,
                i + L2_LOG_VALUE_OFFSET
            );

            // Ensure that the log hasn't been processed already
            require(!_checkBit(processedLogs, uint8(logKey)), "kp");
            processedLogs = _setBit(processedLogs, uint8(logKey));

            // Need to check that each log was sent by the correct address.
            if (logKey == uint256(SystemLogKey.L2_TO_L1_LOGS_TREE_ROOT_KEY)) {
                l2LogsTreeRoot = logValue;
            } else if (
                logKey == uint256(SystemLogKey.TOTAL_L2_TO_L1_PUBDATA_KEY)
            ) {} else if (logKey == uint256(SystemLogKey.STATE_DIFF_HASH_KEY)) {
                stateDiffHash = logValue;
            } else if (
                logKey ==
                uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY)
            ) {
                packedBatchAndL2BlockTimestamp = uint256(logValue);
            } else if (logKey == uint256(SystemLogKey.PREV_BATCH_HASH_KEY)) {
                previousBatchHash = logValue;
            } else if (
                logKey == uint256(SystemLogKey.CHAINED_PRIORITY_TXN_HASH_KEY)
            ) {
                chainedPriorityTxsHash = logValue;
            } else if (
                logKey == uint256(SystemLogKey.NUMBER_OF_LAYER_1_TXS_KEY)
            ) {
                numberOfLayer1Txs = uint256(logValue);
            } else if (
                logKey ==
                uint256(
                    SystemLogKey.EXPECTED_SYSTEM_CONTRACT_UPGRADE_TX_HASH_KEY
                )
            ) {
                require(_expectedSystemContractUpgradeTxHash == logValue, "ut");
            } else {
                revert("ul");
            }
        }

        // We only require 7 logs to be checked, the 8th is if we are expecting a protocol upgrade
        // Without the protocol upgrade we expect 7 logs: 2^7 - 1 = 127
        // With the protocol upgrade we expect 8 logs: 2^8 - 1 = 255
        if (_expectedSystemContractUpgradeTxHash == bytes32(0)) {
            require(processedLogs == 127, "b7");
        } else {
            require(processedLogs == 255, "b8");
        }
    }

    /// @notice Returns true if the bit at index {_index} is 1
    function _checkBit(uint256 _bitMap, uint8 _index)
        internal
        pure
        returns (bool)
    {
        return (_bitMap & (1 << _index)) > 0;
    }

    /// @notice Sets the given bit in {_num} at index {_index} to 1.
    function _setBit(uint256 _bitMap, uint8 _index)
        internal
        pure
        returns (uint256)
    {
        return _bitMap | (1 << _index);
    }
}
