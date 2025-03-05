# LayerZero V2 Bridge

## Description
LayerZero V2 Bridge is a smart contract for cross-chain token transfers using LayerZero V2. The contract allows the owner to add and remove supported tokens, while users can send tokens between networks with a small transaction fee.

## Features
- **Token Management**: The contract owner can manage the list of supported tokens.
- **Cross-Chain Token Transfers**: Users can transfer tokens between different chains with a small fee.
- **Receiving Tokens from Another Chain**: The contract receives and distributes tokens after cross-chain transfers.
- **Flexible Fee Management**: The owner can adjust the fee percentage and fee recipient address.
- **Security Enhancements**: Implements reentrancy protection (`ReentrancyGuard`) and secure token transfers (`SafeERC20`).

## Deployment
### Requirements
- Solidity 0.8.19+
- Foundry (for testing)
- OpenZeppelin Contracts
- LayerZero OApp

### Install Dependencies
```sh
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

### Compilation
```sh
forge build
```

### Deployment (Example in Foundry)
```solidity
LayerZeroBridge bridge = new LayerZeroBridge(endpoint, feeRecipient);
```

## Contract API

### Token Management
```solidity
function addToken(address tokenAddress) external onlyOwner;
function removeToken(address tokenAddress) external onlyOwner;
```

### Fee Management
```solidity
function setFeePercentage(uint256 newFee) external onlyOwner;
function setFeeRecipient(address newRecipient) external onlyOwner;
```

### Sending Tokens
```solidity
function sendToken(address token, uint256 amount, uint32 destination, bytes memory adapterParams) external payable;
```

### Receiving Tokens (LayerZero Call)
```solidity
function _lzReceive(uint32, bytes32, bytes memory payload, address) internal override;
```

## Testing
```sh
forge test
```

## License
MIT
