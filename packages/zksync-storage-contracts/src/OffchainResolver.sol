// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IResolver} from "./interfaces/IResolver.sol";
import {IResolverService} from "./interfaces/IResolverService.sol";
import {StorageProof, StorageProofRequest, StorageProofVerifier} from "./StorageProofVerifier.sol";

contract OffchainResolver is IResolver {
    /// @notice Thrown when an offchain lookup will be performed
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    StorageProofVerifier public storageProofVerifier;
    string public url;

    constructor(string memory _url, StorageProofVerifier _storageProofVerifier) {
        url = _url;
        storageProofVerifier = _storageProofVerifier;
    }

    function resolve(bytes memory _name, bytes memory _data) external view override returns (bytes memory) {
        bytes memory callData = abi.encodeWithSelector(IResolverService.resolve.selector, _name, _data);
        string[] memory urls = new string[](1);
        urls[0] = url;
        revert OffchainLookup(
            address(this),
            urls,
            callData,
            OffchainResolver.resolveWithProof.selector,
            hex""
        );
    }

    /// @notice Callback used by CCIP read compatible clients to verify and parse the response.
    /// @param _response ABI encoded (StorageProof, StorageProofRequest) tuple
    /// @return ABI encoded value of the storage key
    function resolveWithProof(bytes memory _response, bytes memory) external view returns (bytes memory) {
        (StorageProof memory proof, StorageProofRequest memory request) = abi.decode(_response, (StorageProof, StorageProofRequest));
        require(storageProofVerifier.verify(request, proof), "StorageProofVerifier: Invalid storage proof");

        // If there's an address for the name, this should be an address
        // But example code is returning bytes and we're doing the same
        return abi.encodePacked(request.value);
    }

}