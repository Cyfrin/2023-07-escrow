// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract ERC20MockFailedTransfer is ERC20Mock {
    bool public passes;

    constructor() ERC20Mock() {
        passes = false;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        if (passes) {
            return super.transferFrom(sender, recipient, amount);
        } else {
            return passes;
        }
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (passes) {
            return super.transfer(recipient, amount);
        } else {
            return passes;
        }
    }

    function changePasses(bool _passes) public {
        passes = _passes;
    }
}
