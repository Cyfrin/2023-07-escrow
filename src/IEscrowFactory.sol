// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IEscrow} from "./IEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEscrowFactory {
    error EscrowFactory__AddressesDiffer();

    event EscrowCreated(address indexed escrowAddress, address indexed buyer, address indexed seller, address arbiter);

    /// @notice deploy a new escrow contract. The escrow will hold all the funds. The buyer is whoever calls this function.
    /// @param price the price of the escrow. This is the agreed upon price for this service.
    /// @param tokenContract the address of the token contract to use for this escrow, ie USDC, WETH, DAI, etc.
    /// @param seller the address of the seller. This is the one receiving the tokens.
    /// @param arbiter the address of the arbiter. This is the one who will resolve disputes.
    /// @param arbiterFee the fee the arbiter will receive for resolving disputes.
    /// @param salt the salt to use for the escrow contract. This is used to prevent replay attacks.
    /// @return the address of the newly deployed escrow contract.
    function newEscrow(
        uint256 price,
        IERC20 tokenContract,
        address seller,
        address arbiter,
        uint256 arbiterFee,
        bytes32 salt
    ) external returns (IEscrow);
}
