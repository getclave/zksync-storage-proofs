# zksync-storage

Typescript library to generate and verify zkSync storage proofs

## Install
```bash
yarn
```

## Usage
> Verify operation is a very gas-exhaustive function (around 60M gas) and not
> every provider allows us to run it, code is tested to be working on Infura
> providers

```js
import {SepoliaStorageProofProvider} from "@getclave/zksync-storage-proofs";

async function main() {
    const batchNumber = process.argv[2] ? parseInt(process.argv[2]) : undefined;

    const proof = await SepoliaStorageProofProvider.getProof(
        "0x0000000000000000000000000000000000008003",
        "0x8b65c0cf1012ea9f393197eb24619fd814379b298b238285649e14f936a5eb12",
        batchNumber
    );
    console.log("Storage Proof", proof);

    const verified = await SepoliaStorageProofProvider.verifyOnChain(proof);
    console.log("Verified:", verified);
}

main();
```