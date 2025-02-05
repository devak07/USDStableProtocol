

# USDStableProtocol  

## Overview  
This project is an alternative to traditional stablecoins, addressing the risks associated with price fluctuations. Instead of directly purchasing a stablecoin, users acquire a **collateral token**, which is deposited into the system. The system then calculates the USD value based on the collateral token's price. At any time, users can withdraw their funds, and the system mints the necessary tokens accordingly.  

> **Note:** The system currently operates **only on official testnets** due to incompatibility with real Chainlink price feeds.  

For a deeper understanding, refer to the **smart contract files**.  

## Requirements  
- [Foundry](https://github.com/foundry-rs/foundry) (for compiling, deploying, and testing contracts)  
- [Chainlink VRF](https://docs.chain.link/vrf) (for randomness in test price feeds)  
- [Chainlink Keepers](https://docs.chain.link/chainlink-automation/introduction/) (for automated price updates on testnets)  

## Quickstart  

### 1. Install Foundry  
```sh
curl -L https://foundry.paradigm.xyz | bash  
foundryup  
```  

### 2. Clone the repository  
```sh
git clone https://github.com/devak07/USDStableProtocol.git  
cd USDStableProtocol  
```  

### 3. Install dependencies  
```sh
make install  
```  

### 4. Compile the contracts  
```sh
forge build  
```  

## Deployment  

⚠️ **This system can only be deployed on a testnet, not on the mainnet or Anvil local node.**  
Testing can be done on an **Anvil local node**, but deployment must be on an official testnet.  

### Deploying on a Testnet  
1. Set up your environment variables (e.g., private key, RPC URL, etc.).  
2. Run the deployment script:  
   ```sh
   forge script script/Deploy.s.sol --rpc-url <TESTNET_RPC> --private-key <YOUR_PRIVATE_KEY> --broadcast  
   ```  
3. After deployment, set up **Chainlink VRF & Keepers** to ensure automated price updates.  
4. Subscriptions should be set up for the contract address **TestnetPriceRandomUpdate** on the selected testnet.

## Testing  

### Running Tests Locally (Anvil)  

1. Run the tests:  
   ```sh
   forge test  
   ```  

### Running Tests on a Testnet  
1. Deploy contracts to a testnet.  
2. Run test scripts:  
   ```sh
   forge script script/Deploy.s.sol --rpc-url <TESTNET_RPC> --private-key <YOUR_PRIVATE_KEY> --broadcast  
   ```  

## Testing & Security  
✅ All smart contracts have been **fully tested**.  
![Alt text](img/coverage.png)
⚠️ The system **cannot be deployed on the mainnet**. It only works on official testnets due to Chainlink price feed limitations.  

**Author: Andrzej Knapik**
**Github: akdev07**

