// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/StdUtils.sol";
import "../src/LayerZeroBridgeV2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract LayerZeroBridgeTest is Test {
    LayerZeroBridge bridge;
    MockERC20 token;
    address user = address(0x123);
    address feeRecipient = address(0x456);
    address endpoint = address(0x789);

    function setUp() public {
        bridge = new LayerZeroBridge(endpoint, feeRecipient);
        token = new MockERC20("MockToken", "MTK");
        
        vm.prank(bridge.owner());
        bridge.addToken(address(token));

        token.transfer(user, 1000 ether);
    }

    function testAddAndRemoveToken() public {
        assertTrue(bridge.supportedTokens(address(token)));
        
        vm.prank(bridge.owner());
        bridge.removeToken(address(token));
        assertFalse(bridge.supportedTokens(address(token)));
    }

    function testSendToken() public {
        vm.startPrank(user);
        token.approve(address(bridge), 100 ether);
        
        vm.expectEmit(true, true, true, true);
        emit TokenSent(address(token), user, 99.9 ether, 1);
        
        bridge.sendToken(address(token), 100 ether, 1, "");
        
        assertEq(token.balanceOf(address(bridge)), 99.9 ether);
        assertEq(token.balanceOf(feeRecipient), 0.1 ether);
    }

    function testReceiveToken() public {
        vm.prank(user);
        token.transfer(address(bridge), 100 ether);
        
        bytes memory payload = abi.encode(address(token), user, 100 ether);
        
        vm.expectEmit(true, true, true, true);
        emit TokenReceived(address(token), user, 100 ether);
        
        vm.prank(endpoint);
        bridge._lzReceive(1, bytes32(0), payload, address(0));
        
        assertEq(token.balanceOf(user), 100 ether);
    }
}
