// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Dangerously simple registry contract
contract Registry {
    mapping(bytes => address) public names;

    function register(bytes memory _name, address _addr) external {
        names[_name] = _addr;
    }

    function resolve(bytes memory _name) external view returns (address) {
        return names[_name];
    }
}