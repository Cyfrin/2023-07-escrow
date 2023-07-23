// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {EscrowFactory} from "../../src/EscrowFactory.sol";
import {EscrowTestBase} from "../EscrowTestBase.t.sol";
import {IEscrow, Escrow} from "../../src/Escrow.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ERC20MockFailedTransfer} from "../mocks/ERC20MockFailedTransfer.sol";

contract EscrowFactoryTest is Test, EscrowTestBase {
    EscrowFactory public escrowFactory;
    address public constant SOME_DEPLOYER = address(4);

    function setUp() external {
        escrowFactory = new EscrowFactory();
    }

    event EscrowCreated(address indexed escrowAddress, address indexed buyer, address indexed seller, address arbiter);

    modifier hasTokensApprovedForSending() {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE * 2);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE * 2);
        vm.stopPrank();
        _;
    }

    function testComputedAddressEqualsDeployedAddress() public hasTokensApprovedForSending {
        address computedAddress = escrowFactory.computeEscrowAddress(
            type(Escrow).creationCode,
            address(escrowFactory),
            uint256(SALT1),
            PRICE,
            i_tokenContract,
            BUYER,
            SELLER,
            ARBITER,
            ARBITER_FEE
        );
        ERC20Mock(address(i_tokenContract)).mint(computedAddress, PRICE);
        vm.startPrank(address(escrowFactory));
        Escrow escrow = new Escrow{salt: SALT1}(
            PRICE,
            i_tokenContract,
            BUYER,
            SELLER,
            ARBITER,
            ARBITER_FEE
        );
        vm.stopPrank();
        assertEq(computedAddress, address(escrow));
    }

    // This function requires a special setup
    function testRevertsIfTokenTxFails() public {
        // Arrange
        ERC20MockFailedTransfer failedTxToken = new ERC20MockFailedTransfer();
        uint256 amount = PRICE - 1e16;
        ERC20Mock(failedTxToken).mint(BUYER, amount);
        ERC20Mock(failedTxToken).approve(address(escrowFactory), PRICE);

        vm.prank(BUYER);
        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
        escrowFactory.newEscrow(amount, failedTxToken, SELLER, ARBITER, ARBITER_FEE, SALT1);
    }

    function testSameSaltReverts() public hasTokensApprovedForSending {
        vm.prank(BUYER);
        escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);

        vm.prank(BUYER);
        vm.expectRevert();
        escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
    }

    function testCreatingEscrowEmitsEvent() public hasTokensApprovedForSending {
        address computedAddress = escrowFactory.computeEscrowAddress(
            type(Escrow).creationCode,
            address(escrowFactory),
            uint256(SALT1),
            PRICE,
            i_tokenContract,
            BUYER,
            SELLER,
            ARBITER,
            ARBITER_FEE
        );
        vm.prank(BUYER);
        vm.expectEmit(true, true, true, true, address(escrowFactory));
        emit EscrowCreated(computedAddress, BUYER, SELLER, ARBITER);
        escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
    }

    function testCreatingEscrowHasBuyerActuallyBeBuyer() public hasTokensApprovedForSending {
        vm.prank(BUYER);
        IEscrow escrow = escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
        assertEq(BUYER, escrow.getBuyer());
        assertEq(SELLER, escrow.getSeller());
        assertEq(ARBITER, escrow.getArbiter());
    }
}
