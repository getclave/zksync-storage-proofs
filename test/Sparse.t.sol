// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Sparse, TreeEntry, TREE_DEPTH} from "../src/Sparse.sol";
import {Blake2s} from "../src/Blake2s.sol";

contract SparseTest is Test {
    Sparse public sparse;

    function setUp() public {
        sparse = new Sparse();
    }

    function testBlake2() public {
        bytes memory value = hex"98a48e4ed1736188384ae8a79dd21c4d6687e5fd22ca18148906d78736c0d86a";
        Blake2s.toBytes32(value);
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

    function test_compress() public {
        bytes32 lhs = 0x6bbb316d292155ad8d2b47a03504033efbf70074141130e9e346a798f5904921;
        bytes32 rhs = 0xc546f1eef1d499b7b6966254ec541653a205ed4bf7ae3f1ee1ddca773c009e85;
        bytes32 res = sparse.compress(lhs, rhs);
        assertEq(
            res,
            0x65d2ecfac89775755ba564e7a72d108cebffcaa1d138b6d89a59cbcbf664bc6a
        );
    }

    function test_extendMerklePath() public {
        bytes32[] memory path = new bytes32[](0);
        bytes32[] memory full_path = sparse.extendMerklePath(path);
        assertEq(full_path.length, 256);

        bytes32 hash0 = 0x94bb15542026f4f607416f019dffe21bb39bbb32cc92085ab615660a6b5fbef4;
        bytes32 hash1 = 0x7952661ab5d63534c5ea72f81887d8dd6bf514b14c8e9fb714b6feb02efb96a0;
        bytes32 hash2 = 0x3d75808db532e9685bcc7969ad0f5f0872086b24e02b28cdc7df6e3cc1bd2371;
        bytes32 hash253 = 0x7f391690461b8e3468e2f6ba0fcba50df0195bd6d1bb187180650b00b2a13d5a;
        bytes32 hash254 = 0x6bbb316d292155ad8d2b47a03504033efbf70074141130e9e346a798f5904921;
        bytes32 hash255 = 0x395ebe57b2b0ca2592bc9b173eaaedf722c0121cf908386bf2b56d0179fde9c0;

        // Check that the first 3 and last 3 hashes are correct
        assertEq(full_path[0], hash0);
        assertEq(full_path[1], hash1);
        assertEq(full_path[2], hash2);
        assertEq(full_path[253], hash253);
        assertEq(full_path[254], hash254);
        assertEq(full_path[255], hash255);
    }

    function test_foldMerklePath() public {
        TreeEntry memory entry = TreeEntry({
            key: 42366496704336254375416776462386343662429697233927452559041593589277704190797,
            value: 0x0101010101010101010101010101010101010101010101010101010101010101,
            leafIndex: 1
        });
        bytes32[] memory path = new bytes32[](0);

        bytes32 hash = sparse.foldMerklePath(path, entry);
        assertEq(
            hash,
            bytes32(
                0x7f00a6b2eede960857703c8cb9e96f28b910e6693412cea4b006f24239b681e0
            )
        );
    }

    function test_foldMerklePath2() public {
        TreeEntry memory entry = TreeEntry({
            key: 42366496704336254375416776462386343662429697233927452559041593589277704190797,
            value: 0x0101010101010101010101010101010101010101010101010101010101010101,
            leafIndex: 1
        });
        bytes32 leafHash = 0xc546f1eef1d499b7b6966254ec541653a205ed4bf7ae3f1ee1ddca773c009e85;

        bytes32[] memory path  = new bytes32[](2);
        path[0] = 0x0202020202020202020202020202020202020202020202020202020202020202;
        path[1] = 0x0303030303030303030303030303030303030303030303030303030303030303;

        bytes32 expected = sparse.hashBranch(path[0], leafHash);
        expected = sparse.hashBranch(expected, path[1]);

        bytes32 foldedHash = sparse.foldMerklePath(path, entry);
        assertEq(foldedHash, expected);
    }
}
