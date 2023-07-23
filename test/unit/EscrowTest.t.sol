// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {IEscrow, Escrow} from "../../src/Escrow.sol";
import {EscrowFactory} from "../../src/EscrowFactory.sol";
import {EscrowTestBase} from "../EscrowTestBase.t.sol";
import {DeployEscrowFactory} from "../../script/DeployEscrowFactory.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ERC20MockFailedTransfer} from "../mocks/ERC20MockFailedTransfer.sol";

contract EscrowTest is Test, EscrowTestBase {
    EscrowFactory public escrowFactory;
    address public constant SOME_DEPLOYER = address(4);
    IEscrow public escrow;
    uint256 public buyerAward = 0;

    // events
    event Confirmed(address indexed seller);
    event Disputed(address indexed disputer);
    event Resolved(address indexed buyer, address indexed seller);

    function setUp() external {
        DeployEscrowFactory deployer = new DeployEscrowFactory();
        escrowFactory = deployer.run();
    }

    function testDeployEscrowFromFactory() public {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE);
        escrow = escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
        vm.stopPrank();
        assertEq(escrow.getPrice(), PRICE);
        assertEq(address(escrow.getTokenContract()), address(i_tokenContract));
        assertEq(escrow.getBuyer(), BUYER);
        assertEq(escrow.getSeller(), SELLER);
        assertEq(escrow.getArbiter(), ARBITER);
        assertEq(escrow.getArbiterFee(), ARBITER_FEE);
    }

    function testRevertIfFeeGreaterThanPrice() public {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE);
        uint256 arbiterFee = PRICE + 1;
        vm.expectRevert(abi.encodeWithSelector(IEscrow.Escrow__FeeExceedsPrice.selector, PRICE, arbiterFee));
        escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, arbiterFee, SALT1);
        vm.stopPrank();
    }

    function testSellerZeroReverts() public {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE);
        vm.expectRevert(IEscrow.Escrow__SellerZeroAddress.selector);
        escrowFactory.newEscrow(PRICE, i_tokenContract, address(0), ARBITER, ARBITER_FEE, SALT1);
        vm.stopPrank();
    }

    function testTokenZeroReverts() public {
        vm.startPrank(BUYER);
        vm.expectRevert("Address: call to non-contract");
        escrowFactory.newEscrow(PRICE, ERC20Mock(address(0)), SELLER, ARBITER, ARBITER_FEE, SALT1);
        vm.stopPrank();
    }

    function testConstructorBuyerZeroReverts() public {
        vm.expectRevert(IEscrow.Escrow__BuyerZeroAddress.selector);
        new Escrow(PRICE, i_tokenContract, address(0), SELLER, ARBITER, ARBITER_FEE);
    }

    function testConstructorTokenZeroReverts() public {
        vm.expectRevert(IEscrow.Escrow__TokenZeroAddress.selector);
        new Escrow(PRICE, ERC20Mock(address(0)), BUYER, SELLER, ARBITER, ARBITER_FEE);
    }

    /////////////////////
    // Modifiers for next tests //
    ////////////////////
    modifier escrowDeployed() {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE);
        escrow = escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
        vm.stopPrank();
        _;
    }

    /////////////////////
    // confirmReceipt //
    ////////////////////
    // this test needs special setup
    function testConfirmReceiptRevertsOnTokenTxFail() public {
        ERC20MockFailedTransfer tokenContract = new ERC20MockFailedTransfer();
        tokenContract.changePasses(true);
        vm.startPrank(BUYER);
        ERC20Mock(tokenContract).mint(BUYER, PRICE);
        ERC20Mock(tokenContract).approve(address(escrowFactory), PRICE);
        escrow = escrowFactory.newEscrow(PRICE, tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
        tokenContract.changePasses(false);
        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
        escrow.confirmReceipt();
        vm.stopPrank();
    }

    function testConfirmReceiptOnlyByBuyer() public escrowDeployed {
        vm.expectRevert(IEscrow.Escrow__OnlyBuyer.selector);
        vm.prank(ARBITER);
        escrow.confirmReceipt();

        vm.expectRevert();
        vm.prank(SELLER);
        escrow.confirmReceipt();
    }

    function testConfirmReceiptOnlyByBuyerFuzz(address randomAddress) public escrowDeployed {
        vm.assume(randomAddress != BUYER);
        vm.expectRevert(IEscrow.Escrow__OnlyBuyer.selector);
        vm.prank(randomAddress);
        escrow.confirmReceipt();
    }

    function testCanOnlyConfirmInCreatedState() public escrowDeployed {
        vm.prank(BUYER);
        escrow.confirmReceipt();

        vm.expectRevert(
            abi.encodeWithSelector(
                IEscrow.Escrow__InWrongState.selector, IEscrow.State.Confirmed, IEscrow.State.Created
            )
        );
        vm.prank(BUYER);
        escrow.confirmReceipt();
    }

    function testTransfersTokenOutOfContract() public escrowDeployed {
        vm.prank(BUYER);
        escrow.confirmReceipt();
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(address(escrow)), 0);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(SELLER), PRICE);
    }

    function testStateChangesOnConfirmedReceipt() public escrowDeployed {
        vm.prank(BUYER);
        escrow.confirmReceipt();
        assertEq(uint256(escrow.getState()), uint256(IEscrow.State.Confirmed));
    }

    function testConfirmReceiptEmitsEvent() public escrowDeployed {
        vm.prank(BUYER);
        vm.expectEmit(true, false, false, false, address(escrow));
        emit Confirmed(SELLER);
        escrow.confirmReceipt();
    }

    /////////////////////
    // initiateDispute //
    ////////////////////
    function testOnlyBuyerOrSellerCanCallinitiateDispute(address randomAdress) public escrowDeployed {
        vm.assume(randomAdress != BUYER && randomAdress != SELLER);
        vm.expectRevert(IEscrow.Escrow__OnlyBuyerOrSeller.selector);
        vm.prank(randomAdress);
        escrow.initiateDispute();
    }

    function testCanOnlyInitiateDisputeInConfirmedState() public escrowDeployed {
        vm.prank(BUYER);
        escrow.confirmReceipt();

        vm.prank(BUYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEscrow.Escrow__InWrongState.selector, IEscrow.State.Confirmed, IEscrow.State.Created
            )
        );
        escrow.initiateDispute();
    }

    function testInitiateDisputeChangesState() public escrowDeployed {
        vm.prank(BUYER);
        escrow.initiateDispute();
        assertEq(uint256(escrow.getState()), uint256(IEscrow.State.Disputed));
    }

    function testInitiateDisputeEmitsEvent() public escrowDeployed {
        vm.prank(BUYER);
        vm.expectEmit(true, false, false, false, address(escrow));
        emit Disputed(BUYER);
        escrow.initiateDispute();
    }

    function testInitiateDisputeWithoutArbiterReverts() public {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE);
        escrow = escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, address(0), ARBITER_FEE, SALT1);
        vm.expectRevert(IEscrow.Escrow__DisputeRequiresArbiter.selector);
        escrow.initiateDispute();
        vm.stopPrank();
    }

    /////////////////////
    // resolveDispute //
    ////////////////////
    function testOnlyArbiterCanCallResolveDispute(address randomAdress) public escrowDeployed {
        vm.assume(randomAdress != ARBITER);
        vm.expectRevert(IEscrow.Escrow__OnlyArbiter.selector);
        vm.prank(randomAdress);
        escrow.resolveDispute(buyerAward);
    }

    function testCanOnlyResolveInDisputedState() public escrowDeployed {
        vm.prank(ARBITER);
        vm.expectRevert(
            abi.encodeWithSelector(IEscrow.Escrow__InWrongState.selector, IEscrow.State.Created, IEscrow.State.Disputed)
        );
        escrow.resolveDispute(buyerAward);

        vm.prank(BUYER);
        escrow.confirmReceipt();

        vm.prank(ARBITER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEscrow.Escrow__InWrongState.selector, IEscrow.State.Confirmed, IEscrow.State.Disputed
            )
        );
        escrow.resolveDispute(buyerAward);
    }

    function testResolveDisputeChangesState() public escrowDeployed {
        vm.prank(BUYER);
        escrow.initiateDispute();

        vm.prank(ARBITER);
        escrow.resolveDispute(buyerAward);
        assertEq(uint256(escrow.getState()), uint256(IEscrow.State.Resolved));
    }

    function testResolveDisputeTransfersTokens() public escrowDeployed {
        uint256 buyerStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(BUYER);
        uint256 sellerStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(SELLER);
        uint256 arbiterStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(ARBITER);

        buyerAward = 1e16;
        vm.prank(BUYER);
        escrow.initiateDispute();

        vm.prank(ARBITER);
        escrow.resolveDispute(buyerAward);

        uint256 expectedSellarReward = PRICE - buyerAward - ARBITER_FEE;

        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(address(escrow)), 0);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(BUYER), buyerStartingBalance + buyerAward);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(SELLER), sellerStartingBalance + expectedSellarReward);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(ARBITER), arbiterStartingBalance + ARBITER_FEE);
    }

    function testResolveDisputeWithBuyerAward() public escrowDeployed {
        uint256 buyerStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(BUYER);
        uint256 arbiterStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(ARBITER);
        uint256 escrowStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(address(escrow));

        vm.prank(BUYER);
        escrow.initiateDispute();

        buyerAward = 1;
        vm.prank(ARBITER);
        escrow.resolveDispute(buyerAward);

        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(address(escrow)), 0);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(BUYER), buyerStartingBalance + buyerAward);
        assertEq(
            ERC20Mock(address(i_tokenContract)).balanceOf(SELLER), escrowStartingBalance - buyerAward - ARBITER_FEE
        );
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(ARBITER), arbiterStartingBalance + ARBITER_FEE);
    }

    function testResolveDisputeFeeExceedsBalance() public escrowDeployed {
        vm.prank(BUYER);
        escrow.initiateDispute();

        vm.prank(ARBITER);
        uint256 disputerBuyerAward = PRICE * 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                IEscrow.Escrow__TotalFeeExceedsBalance.selector, PRICE, disputerBuyerAward + ARBITER_FEE
            )
        );
        escrow.resolveDispute(disputerBuyerAward);
    }

    function testResolveDisputeZeroSellerTransfer() public escrowDeployed {
        uint256 buyerStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(BUYER);
        uint256 sellerStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(SELLER);
        uint256 arbiterStartingBalance = ERC20Mock(address(i_tokenContract)).balanceOf(ARBITER);

        vm.prank(BUYER);
        escrow.initiateDispute();

        vm.prank(ARBITER);
        uint256 disputeBuyerAward = PRICE - ARBITER_FEE;

        escrow.resolveDispute(disputeBuyerAward);

        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(address(escrow)), 0);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(BUYER), buyerStartingBalance + disputeBuyerAward);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(SELLER), sellerStartingBalance);
        assertEq(ERC20Mock(address(i_tokenContract)).balanceOf(ARBITER), arbiterStartingBalance + ARBITER_FEE);
    }
}
