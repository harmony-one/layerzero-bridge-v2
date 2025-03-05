// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/OApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LayerZeroBridge is OApp, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public contractBalances;
    uint256 public feePercentage = 10; // 0.1% fee (1000 = 1%)
    address public feeRecipient;

    event TokenAdded(address indexed tokenAddress);
    event TokenRemoved(address indexed tokenAddress);
    event TokenSent(address indexed tokenAddress, address indexed sender, uint256 amount, uint32 destination);
    event TokenReceived(address indexed tokenAddress, address indexed recipient, uint256 amount);
    event FeeUpdated(uint256 newFeePercentage);
    event FeeRecipientUpdated(address newFeeRecipient);

    constructor(address endpoint, address _feeRecipient) OApp(endpoint) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    function addToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        supportedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    function removeToken(address tokenAddress) external onlyOwner {
        require(supportedTokens[tokenAddress], "Token not supported");
        delete supportedTokens[tokenAddress];
        emit TokenRemoved(tokenAddress);
    }

    function setFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee too high");
        feePercentage = newFee;
        emit FeeUpdated(newFee);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function sendToken(address tokenAddress, uint256 amount, uint32 destination, bytes memory adapterParams) external payable nonReentrant {
        require(supportedTokens[tokenAddress], "Token not supported");
        require(amount > 0, "Amount must be greater than zero");
        
        uint256 fee = (amount * feePercentage) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        if (fee > 0) {
            IERC20(tokenAddress).safeTransfer(feeRecipient, fee);
        }
        contractBalances[tokenAddress] += amountAfterFee;

        _lzSend(destination, abi.encode(tokenAddress, msg.sender, amountAfterFee), adapterParams, msg.value);
        emit TokenSent(tokenAddress, msg.sender, amountAfterFee, destination);
    }

    function _lzReceive(uint32, bytes32, bytes memory payload, address) internal override nonReentrant {
        (address tokenAddress, address recipient, uint256 amount) = abi.decode(payload, (address, address, uint256));
        require(supportedTokens[tokenAddress], "Token not supported");
        require(contractBalances[tokenAddress] >= amount, "Insufficient contract balance");

        contractBalances[tokenAddress] -= amount;
        IERC20(tokenAddress).safeTransfer(recipient, amount);
        emit TokenReceived(tokenAddress, recipient, amount);
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        require(contractBalances[tokenAddress] >= amount, "Insufficient balance");
        contractBalances[tokenAddress] -= amount;
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }
}
