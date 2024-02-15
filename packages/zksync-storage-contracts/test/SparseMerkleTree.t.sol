// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {SparseMerkleTree, TreeEntry, TREE_DEPTH} from "../src/SparseMerkleTree.sol";
import {Blake2s} from "../src/Blake2s.sol";

contract SparseTest is Test {
    SparseMerkleTree public sparse;

    function setUp() public {
        sparse = new SparseMerkleTree();
    }

    function test_hash() public pure {
        Blake2s.toBytes32(hex"deadbeef");
    }

    function test_hashLeaf() public {
        TreeEntry memory entry = TreeEntry({
            key: 42366496704336254375416776462386343662429697233927452559041593589277704190797,
            value: 0x0101010101010101010101010101010101010101010101010101010101010101,
            leafIndex: 1
        });
        bytes32 hashValue = sparse.hashLeaf(entry.leafIndex, entry.value);
        assertEq(
            hashValue,
            0x52f28950612240cb4fb218fbf6df83f6dbe271c056900b11966cfb9404c1dce0
        );
    }

    function test_hashBranch() public {
        bytes32 lhs = 0x6bbb316d292155ad8d2b47a03504033efbf70074141130e9e346a798f5904921;
        bytes32 rhs = 0xc546f1eef1d499b7b6966254ec541653a205ed4bf7ae3f1ee1ddca773c009e85;
        bytes32 res = sparse.hashBranch(lhs, rhs);
        assertEq(
            res,
            0x65d2ecfac89775755ba564e7a72d108cebffcaa1d138b6d89a59cbcbf664bc6a
        );
    }

    function test_getRootHash() public {
        address account = 0x0000000000000000000000000000000000008003;
        TreeEntry memory entry = TreeEntry({
            key: 0x8b65c0cf1012ea9f393197eb24619fd814379b298b238285649e14f936a5eb12,
            value: 0x0000000000000000000000000000000000000000000000000000000000000081,
            leafIndex: 27900957
        });
        bytes32[] memory proof = new bytes32[](29);
        proof[ 0] = 0xed71b28e74e0c345ccea429109d91e298de836bf32290bfda4210d76bb646cd7;
        proof[ 1] = 0x8af18107777760cbe302f71d4b1f34b4938de74d5846a5f397fde3446e33ec3a;
        proof[ 2] = 0xc34095206a7e18c8ac745c8619f36b572ad998b82cb44029b9f154bb52e6baca;
        proof[ 3] = 0x5651a358ee5a251ce5ae208d34a656d42ea2b2d2fc39c99585031a315c9e3bed;
        proof[ 4] = 0xedfba15a198418927ad5a6d01a40199b2ba5a6641fcdb830c8633b26a0f56c12;
        proof[ 5] = 0x4dcd3694b48be20029231dcd8c9cafa2918b74fbfc27d091c7e4f302f4f40e5e;
        proof[ 6] = 0x3602bb54759588254273899f6b644c3bcc237268527ea064248f6739464e9a7a;
        proof[ 7] = 0x8f21b220b7a2434e905f55add2c91f0a4f8ac76ed78c5f497602430818c554b9;
        proof[ 8] = 0x12cbfcf823575cdf5670361f33bea5ab5074cbf2a4161dd8b6f256abd9865f71;
        proof[ 9] = 0x3cd29f2eae832264383c0d36cdace1c6f7f2fdc0986fc7f4a9e03f63947a9067;
        proof[10] = 0x56c56aa1c6fbba4c06a1f59e900474c03865323cd4214f485bb612362f43a6bd;
        proof[11] = 0x3d327832337ddafb36270d814d21100c49d258afea7e651d1762fcdf44704356;
        proof[12] = 0x5f563e5f1a5bbacddfcbd1f92f6254c4ed4a4e1c3f6072ed4a339cc702e849d7;
        proof[13] = 0xb05359a447c3932f484596cadcb51ae96d7982fa6a4b6f5eaff69288d76dc439;
        proof[14] = 0x37a12b6176c62876b5518cef46bc84469d06c3440dc14b215107fefbb86616c3;
        proof[15] = 0x01ca2e9b062fcfbb33e759050a358be457bb1e921d4241813ee2d8ba80706123;
        proof[16] = 0x95de301f0bdb83fdf9fd5493de4a38c75d3d6dfc665e5ed960ffa56634afcd1f;
        proof[17] = 0xb60433819958ce96c7899aad995af89cd7c7fb2155c63939eee29a5ac8abc275;
        proof[18] = 0xd2b9fdff34156cb0aedbf0aada02354e4651921695192daef84c4a9becff0d25;
        proof[19] = 0x41a887db53f910b460886d06eb79ec516e03acb3ed8bb5f9fdf9d883d664bcd6;
        proof[20] = 0xc80b0443c7bee5c8e31e3449dad0affcedfb75f4a8d310a66b2908b9fdb8cc88;
        proof[21] = 0x88ae8315e8916d2311e923eb58087223dda8e686ad13fb1d7005e98ea982c310;
        proof[22] = 0x4513cb503e66d3752673da206441ac555236486809e44c7a81369467d82d30d2;
        proof[23] = 0x6d639e221808c9cb69aa5b19a8b3cc55b3e2701b4bff109aed9e5644cc64d323;
        proof[24] = 0x42c0e6cfbd0f0bc0505538ec04c120a21477c109b0a576247d7d45919d400ede;
        proof[25] = 0x9cb345b482f45358dd0a57afce927d7b85756f6d49c2ae0dc7f7908fb27d3cc2;
        proof[26] = 0x0a39e3389d2437d160f3d95cdf30f61c1afd52a2f82cafd2ac32a6b6ea823e9b;
        proof[27] = 0x9ebd7b37a21fb0c74d0040a941038887caf4e4c7dfaa182b82915cacc6191025;
        proof[28] = 0x4550ab30af8c76557a74d051eb43a964889d383d6da343c6a4f4799595d86f9c;

        bytes32 rootHash = sparse.getRootHash(proof, entry, account);
        assertEq(rootHash, 0xcffaa7db2e75d764007ded235fb8f482bc8a43ce14e35a4f1a979c485f3c7fc6);
    }
}
