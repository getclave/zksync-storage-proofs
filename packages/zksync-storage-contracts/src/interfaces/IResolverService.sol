// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {StorageProof, StorageProofRequest} from "../StorageProofVerifier.sol";

interface IResolverService {
    function resolve(bytes calldata name, bytes calldata data) external view returns(StorageProof memory proof, StorageProofRequest memory request);
}