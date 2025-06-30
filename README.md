# Satoshi Vault - STX Lending with Bitcoin Collateral

A decentralized lending protocol built on Stacks that enables users to borrow STX tokens using Bitcoin as collateral, leveraging Stacks' unique Bitcoin connection for secure cross-chain lending.

## Overview

Satoshi Vault is a DeFi lending protocol that bridges Bitcoin and the Stacks ecosystem. Users can deposit Bitcoin as collateral to borrow STX tokens, while STX holders can provide liquidity to earn interest. The protocol maintains security through over-collateralization and automatic liquidation mechanisms.

## Key Features

- **Bitcoin-Collateralized Lending**: Use Bitcoin as collateral to borrow STX tokens
- **Liquidity Pool**: STX holders can supply liquidity and earn interest
- **Over-Collateralization**: Maximum 75% loan-to-value ratio for safety
- **Automatic Interest**: 5% annual interest rate with block-based compounding
- **Liquidation Protection**: 80% liquidation threshold protects lenders
- **Oracle Integration**: BTC price feeds for accurate collateral valuation

## Protocol Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Max LTV | 75% | Maximum loan-to-value ratio |
| Liquidation Threshold | 80% | LTV ratio that triggers liquidation |
| Interest Rate | 5% | Annual interest rate |
| Minimum Loan | 1 STX | Minimum borrowable amount |

## Smart Contract Functions

### For Borrowers

#### `create-loan`
```clarity
(create-loan (btc-collateral uint) (stx-amount uint))
```
Create a new loan by depositing Bitcoin collateral and borrowing STX tokens.

**Parameters:**
- `btc-collateral`: Amount of Bitcoin collateral in satoshis
- `stx-amount`: Amount of STX tokens to borrow in micro-STX

**Requirements:**
- LTV ratio must be ≤ 75%
- Minimum loan amount: 1 STX
- Sufficient liquidity available

#### `repay-loan`
```clarity
(repay-loan (loan-id uint) (repay-amount uint))
```
Make partial or full repayment on an existing loan.

**Parameters:**
- `loan-id`: ID of the loan to repay
- `repay-amount`: Amount to repay in micro-STX

### For Liquidity Providers

#### `supply-stx`
```clarity
(supply-stx (amount uint))
```
Deposit STX tokens to the liquidity pool to earn interest.

**Parameters:**
- `amount`: Amount of STX to supply in micro-STX

#### `withdraw-stx`
```clarity
(withdraw-stx (amount uint))
```
Withdraw previously supplied STX tokens from the liquidity pool.

**Parameters:**
- `amount`: Amount of STX to withdraw in micro-STX

### For Liquidators

#### `liquidate-loan`
```clarity
(liquidate-loan (loan-id uint))
```
Liquidate an unhealthy loan (LTV > 80%) and claim the collateral.

**Parameters:**
- `loan-id`: ID of the loan to liquidate

### Administrative

#### `update-btc-price`
```clarity
(update-btc-price (new-price uint))
```
Update the BTC price oracle (contract owner only).

**Parameters:**
- `new-price`: New BTC price in micro-STX

## Read-Only Functions

### `get-loan`
```clarity
(get-loan (loan-id uint))
```
Retrieve detailed information about a specific loan including current interest, total debt, and health status.

### `get-user-loans`
```clarity
(get-user-loans (user principal))
```
Get list of loan IDs for a specific user.

### `get-vault-stats`
```clarity
(get-vault-stats)
```
Get overall vault statistics including total supply, borrows, and utilization rate.

### `get-user-liquidity`
```clarity
(get-user-liquidity (user principal))
```
Get the amount of STX a user has supplied to the liquidity pool.

## Usage Examples

### Creating a Loan

```clarity
;; Deposit 0.1 BTC (10,000,000 satoshis) as collateral to borrow 30 STX
(contract-call? .satoshi-vault create-loan u10000000 u30000000)
```

### Supplying Liquidity

```clarity
;; Supply 100 STX to the liquidity pool
(contract-call? .satoshi-vault supply-stx u100000000)
```

### Repaying a Loan

```clarity
;; Repay 10 STX on loan ID 1
(contract-call? .satoshi-vault repay-loan u1 u10000000)
```

## Risk Management

### Collateralization
- All loans are over-collateralized with a maximum 75% LTV ratio
- Bitcoin collateral value is calculated using the protocol's price oracle
- Interest accrues continuously based on block height

### Liquidation
- Loans become eligible for liquidation when LTV exceeds 80%
- Liquidators can claim the Bitcoin collateral by closing unhealthy positions
- Automatic interest updates ensure accurate debt calculations

### Oracle Security
- BTC price updates are restricted to the contract owner
- Price feeds should be updated regularly to maintain accuracy
- Consider implementing decentralized oracle solutions for production

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller not authorized for this action |
| u101 | ERR_INVALID_AMOUNT | Invalid amount specified |
| u102 | ERR_INSUFFICIENT_COLLATERAL | Not enough collateral for loan |
| u103 | ERR_LOAN_NOT_FOUND | Loan does not exist |
| u104 | ERR_LOAN_ALREADY_EXISTS | Loan already exists |
| u105 | ERR_INSUFFICIENT_LIQUIDITY | Not enough STX in liquidity pool |
| u106 | ERR_LOAN_EXPIRED | Loan has expired |
| u107 | ERR_INVALID_LTV | Loan-to-value ratio exceeds maximum |
| u108 | ERR_REPAYMENT_FAILED | Loan repayment failed |

## Deployment

### Prerequisites
- Clarinet CLI installed
- Stacks development environment set up

### Testing
```bash
clarinet check
clarinet test
```

### Deployment Steps
1. Update the `Clarinet.toml` file with contract details
2. Test thoroughly on testnet
3. Deploy to mainnet using Clarinet or Stacks CLI

## Security Considerations

### Audit Recommendations
- Professional smart contract audit before mainnet deployment
- Comprehensive testing of liquidation mechanisms
- Oracle manipulation attack vectors
- Integer overflow/underflow protections

### Production Considerations
- Implement decentralized price oracles
- Add emergency pause functionality
- Consider governance mechanisms for parameter updates
- Implement timelock controls for sensitive functions

## Integration with Bitcoin

This contract is designed to work with Stacks' Bitcoin integration features:

- **Bitcoin Collateral**: In production, integrate with `clarity-bitcoin` library for actual Bitcoin deposits
- **Cross-Chain Verification**: Use Stacks' Bitcoin finality for collateral confirmation
- **Bitcoin Withdrawals**: Implement Bitcoin payout mechanisms for liquidations

## Future Enhancements

- **Multi-Asset Collateral**: Support for other cryptocurrencies
- **Variable Interest Rates**: Dynamic rates based on utilization
- **Governance Token**: DAO governance for protocol parameters
- **Flash Loans**: Uncollateralized lending for arbitrage
- **Yield Farming**: Additional rewards for liquidity providers


## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request


