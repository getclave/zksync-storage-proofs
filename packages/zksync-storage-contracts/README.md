# zkSync Storage Contracts

## Deployment

🚧

## Tests

```bash
forge test # Runs all tests
```

## Dependencies

This repo uses a slightly modified version of https://github.com/AlexNi245/blake2s-solidity
for the Solidity implementation of Blake2S hash.

## Usage

In order to verify a storage proof:

1. Get storage proof from @getclave/zksync-storage-proofs
2. Pass it to the `StorageProofVerifier#verify` function to verify

> This takes around 60M gas so only call it inside view functions

> Most of the time it will make sense to override `account`, `key`
> fields to make sure proof is proving the correct content.

```solidity
import {StorageProof, StorageProofVerifier} from "./StorageProofVerifier.sol";

contract MyProofVerifier {
    StorageProofVerifier verifier;

    constructor(StorageProofVerifier _verifier) {
        verifier = _verifier;
    }

    function checkProof(
        address account,
        uint256 key,
        StorageProof memory proof
    ) external view returns (bool) {
        proof.account = account;
        proof.key = key;

        return verifier.verify(proof);
    }
}
```

You can also check out the [demo](./src/demo/) for an example implementation
