// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/OApp.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenWrapper is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}

contract LayerZeroReceiver is OApp, Ownable, ReentrancyGuard {
    mapping(address => address) public wrappedTokens;
    address public feeRecipient;
    
    event TokenWrapped(address indexed originalToken, address wrapperToken);
    event TokenReceived(address indexed token, address indexed recipient, uint256 amount);
    event TokenSent(address indexed token, address indexed sender, uint256 amount, uint32 destination);

    constructor(address endpoint, address _feeRecipient) OApp(endpoint) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    function _registerWrappedToken(address originalToken) internal returns (address) {
        require(originalToken != address(0), "Invalid token address");
        require(wrappedTokens[originalToken] == address(0), "Wrapper already exists");
        
        string memory name = string(abi.encodePacked("Wrapped ", ERC20(originalToken).name()));
        string memory symbol = string(abi.encodePacked("w", ERC20(originalToken).symbol()));
        
        TokenWrapper wrapper = new TokenWrapper(name, symbol);
        wrappedTokens[originalToken] = address(wrapper);
        emit TokenWrapped(originalToken, address(wrapper));
        return address(wrapper);
    }

    function _lzReceive(uint32, bytes32, bytes memory payload, address) internal override nonReentrant {
        (address originalToken, address recipient, uint256 amount) = abi.decode(payload, (address, address, uint256));
        address wrapperToken = wrappedTokens[originalToken];
        
        if (wrapperToken == address(0)) {
            wrapperToken = _registerWrappedToken(originalToken);
        }
        
        TokenWrapper(wrapperToken).mint(recipient, amount);
        emit TokenReceived(wrapperToken, recipient, amount);
    }

    function sendToken(address wrapperToken, uint256 amount, uint32 destination, bytes memory adapterParams) external payable nonReentrant {
        require(wrappedTokens[wrapperToken] != address(0), "Not a wrapped token");
        require(amount > 0, "Amount must be greater than zero");
        
        TokenWrapper(wrapperToken).burn(msg.sender, amount);
        _lzSend(destination, abi.encode(wrapperToken, msg.sender, amount), adapterParams, msg.value);
        emit TokenSent(wrapperToken, msg.sender, amount, destination);
    }
}