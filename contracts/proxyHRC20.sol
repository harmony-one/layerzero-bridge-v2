// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/OApp.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenWrapper is ERC20 {
    address public bridge;

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can mint/burn");
        _;
    }

    constructor(string memory name, string memory symbol, address _bridge) ERC20(name, symbol) {
        bridge = _bridge;
    }

    function mint(address account, uint256 amount) external onlyBridge {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyBridge {
        _burn(account, amount);
    }
}

contract LayerZeroReceiver is OApp, Ownable, ReentrancyGuard {
    mapping(address => address) public wrappedTokens;
    address public feeRecipient;
    uint256 public feePercentage = 10; // 0.1%
    mapping(uint32 => bool) public supportedChains;
    
    event TokenWrapped(address indexed originalToken, address wrapperToken);
    event TokenReceived(address indexed originalToken, address indexed wrapperToken, address indexed recipient, uint256 amount);
    event TokenSent(address indexed originalToken, address indexed wrapperToken, address indexed sender, uint256 amount, uint32 destination, uint256 fee);
    event FeeUpdated(uint256 newFee);
    event SupportedChainUpdated(uint32 chainId, bool supported);

    constructor(address endpoint, address _feeRecipient) OApp(endpoint) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    function _registerWrappedToken(address originalToken) internal returns (address) {
        require(originalToken != address(0), "Invalid token address");
        
        if (wrappedTokens[originalToken] != address(0)) {
            return wrappedTokens[originalToken];
        }
        
        string memory name = string(abi.encodePacked("Wrapped ", ERC20(originalToken).name()));
        string memory symbol = string(abi.encodePacked("w", ERC20(originalToken).symbol()));
        
        TokenWrapper wrapper = new TokenWrapper(name, symbol, address(this));
        wrappedTokens[originalToken] = address(wrapper);
        emit TokenWrapped(originalToken, address(wrapper));
        return address(wrapper);
    }

    function _lzReceive(uint32, bytes32, bytes memory payload, address) internal override nonReentrant {
        (address originalToken, address recipient, uint256 amount) = abi.decode(payload, (address, address, uint256));
        address wrapperToken = _registerWrappedToken(originalToken);
        
        TokenWrapper(wrapperToken).mint(recipient, amount);
        emit TokenReceived(originalToken, wrapperToken, recipient, amount);
    }

    function sendToken(address wrapperToken, uint256 amount, uint32 destination, bytes memory adapterParams) external payable nonReentrant {
        require(wrappedTokens[wrapperToken] != address(0), "Not a wrapped token");
        require(amount > 0, "Amount must be greater than zero");
        require(supportedChains[destination], "Unsupported destination chain");
        
        uint256 fee = (amount * feePercentage) / 10000;
        uint256 sendAmount = amount - fee;
        
        TokenWrapper(wrapperToken).burn(msg.sender, amount);
        if (fee > 0) {
            TokenWrapper(wrapperToken).mint(feeRecipient, fee);
        }
        
        _lzSend(destination, abi.encode(wrapperToken, msg.sender, sendAmount), adapterParams, msg.value);
        emit TokenSent(wrapperToken, wrappedTokens[wrapperToken], msg.sender, sendAmount, destination, fee);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee too high"); // Max 1%
        feePercentage = newFee;
        emit FeeUpdated(newFee);
    }

    function updateSupportedChain(uint32 chainId, bool supported) external onlyOwner {
        supportedChains[chainId] = supported;
        emit SupportedChainUpdated(chainId, supported);
    }
}
