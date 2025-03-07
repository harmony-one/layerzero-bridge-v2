// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LayerZeroReceiver.sol";

contract LayerZeroReceiverTest is Test {
    LayerZeroReceiver receiver;
    TokenWrapper wrappedToken;
    address user = address(0x123);
    address feeRecipient = address(0x456);
    uint32 destinationChain = 1;

    function setUp() public {
        receiver = new LayerZeroReceiver(address(this), feeRecipient);
        wrappedToken = new TokenWrapper("Wrapped Token", "wTKN", address(receiver));
    }

    function testRegisterWrappedToken() public {
        address originalToken = address(0x789);
        address wrapper = receiver._registerWrappedToken(originalToken);
        assertEq(receiver.wrappedTokens(originalToken), wrapper);
    }

    function testDeployNewWrappedToken() public {
        address originalToken = address(0x999);
        assertEq(receiver.wrappedTokens(originalToken), address(0));
        
        address wrapper = receiver._registerWrappedToken(originalToken);
        assertTrue(wrapper != address(0));
        assertEq(receiver.wrappedTokens(originalToken), wrapper);
    }

    function testSendToken() public {
        address originalToken = address(wrappedToken);
        receiver.updateSupportedChain(destinationChain, true);
        
        wrappedToken.mint(user, 1000);
        vm.startPrank(user);
        wrappedToken.approve(address(receiver), 1000);
        receiver.sendToken(originalToken, 1000, destinationChain, "");
        vm.stopPrank();
        
        assertEq(wrappedToken.balanceOf(user), 0);
    }

    function testReceiveToken() public {
        address originalToken = address(0x789);
        address recipient = address(0xabc);
        uint256 amount = 1000;
        
        bytes memory payload = abi.encode(originalToken, recipient, amount);
        receiver._lzReceive(destinationChain, bytes32(0), payload, address(this));
        
        address wrapper = receiver.wrappedTokens(originalToken);
        assertEq(ERC20(wrapper).balanceOf(recipient), amount);
    }
}