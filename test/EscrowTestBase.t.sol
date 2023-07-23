// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowTestBase {
    bytes32 public constant SALT1 = bytes32(uint256(keccak256(abi.encodePacked("test"))));
    bytes32 public constant SALT2 = bytes32(uint256(keccak256(abi.encodePacked("test2"))));
    uint256 public constant PRICE = 1e18;
    IERC20 public immutable i_tokenContract;
    address public constant BUYER = address(1);
    address public constant SELLER = address(2);
    address public constant ARBITER = address(3);
    uint256 public constant ARBITER_FEE = 1e16;

    constructor() {
        i_tokenContract = IERC20(new ERC20Mock());
    }
}
