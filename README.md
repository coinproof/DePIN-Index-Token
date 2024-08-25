
# Guide to Deploy and Interact with the `DePINIndexToken` Contract

This guide will walk you through the steps to deploy the `DePINIndexToken` contract using **Hardhat** or **Remix IDE** and demonstrate how to interact with the contract functions, including owner functions, staking, and unstaking.

---

## **Deploying the Contract**

### 1. **Using Hardhat**

#### **Prerequisites:**
- Node.js and npm installed.
- Hardhat installed (`npm install --save-dev hardhat`).
- Metamask or any other wallet extension.

#### **Steps:**

1. **Initialize a Hardhat Project:**

   ```bash
   npx hardhat init
   cd your_project_directory
   ```

2. **Install Dependencies:**

   ```bash
   npm install @openzeppelin/contracts
   ```

3. **Create a New Solidity File:**

   Inside the `contracts` folder, create a new file named `DePINIndexToken.sol` and paste the contract code provided.

4. **Update DePIN tokens ERC20 addresses**: inside the constructor before deploying.

5. **Create a Deployment Script:**

   Inside the `scripts` folder, create a new file named `deploy.js`:

   ```javascript
   async function main() {
     const [deployer] = await ethers.getSigners();
     console.log("Deploying contracts with the account:", deployer.address);

     const DePINIndexToken = await ethers.getContractFactory("DePINIndexToken");
     const depinIndexToken = await DePINIndexToken.deploy();

     console.log("DePIN Index Token deployed to:", depinIndexToken.address);
   }

   main()
     .then(() => process.exit(0))
     .catch((error) => {
       console.error(error);
       process.exit(1);
     });
   ```

6. **Compile the Contract:**

   ```bash
   npx hardhat compile
   ```

7. **Deploy the Contract to a Network:**

   - Configure the `hardhat.config.js` file with your network settings (e.g., Ropsten, Rinkeby, etc.).
   - Deploy to the selected network:

   ```bash
   npx hardhat run scripts/deploy.js --network your_network
   ```

8. **Verify Deployment:**

   Once deployed, note down the contract address from the output for further interaction.

### 2. **Using Remix IDE**

#### **Steps:**

1. **Open Remix IDE:**

   Go to [Remix IDE](https://remix.ethereum.org/).

2. **Create a New File:**

   In the Remix file explorer, create a new file named `DePINIndexToken.sol` and paste the contract code. Change the DePIN ERC20 contract addresses inside the constructor.

3. **Compile the Contract:**

   - Select the Solidity compiler version `0.8.26`.
   - Click "Compile DePINIndexToken.sol".

4. **Deploy the Contract:**

   - Go to the "Deploy & Run Transactions" tab.
   - Select the appropriate environment (e.g., Injected Web3 for Metamask).
   - Click "Deploy" and confirm the transaction in your wallet.

5. **Verify Deployment:**

   After deployment, the contract will appear under "Deployed Contracts" with its address.

---

## **Interacting with the Contract**

### **1. Interacting via Hardhat Console**

To interact with the deployed contract using Hardhat, use the Hardhat console:

```bash
npx hardhat console --network your_network
```

#### **Load the Contract:**

```javascript
const contractAddress = "your_contract_address";
const DePINIndexToken = await ethers.getContractFactory("DePINIndexToken");
const depinIndexToken = await DePINIndexToken.attach(contractAddress);
```

### **2. Interacting via Remix**

- Go to the "Deployed Contracts" section.
- Use the provided interface to interact with the contract functions.

### **3. Contract Functions**

#### **Owner Functions:**

1. **Update Staking Duration:**

   - **Function:** `updateStakingDuration(uint256 _duration)`
   - **Description:** Updates the staking duration. Only callable by the contract owner.
   - **Example:**

   ```javascript
   await depinIndexToken.updateStakingDuration(2); // Sets staking duration to 2 days
   ```

2. **Update Token Price:**

   - **Function:** `updateTokenPrice(uint256 tokenID, uint256 newPrice)`
   - **Description:** Updates the price of the specified DePIN token. Only callable by the contract owner.
   - **Example:**

   ```javascript
   await depinIndexToken.updateTokenPrice(1, 3000); // Updates price for tokenID 1 to 3000, where 1 USDT = 3000 DePIN Token1
   ```

#### **User Functions:**

1. **Staking Tokens:**

   - **Function:** `stake(uint256 tokenID, uint256 amount)`
   - **Description:** Allows users to stake DePIN tokens to mint index tokens. The staked amount is locked for the specified duration.
   - **Example:**

   ```javascript
   await depinIndexToken.stake(1, ethers.utils.parseEther("10")); // Stake 10 DePIN tokens of type 1
   ```

2. **Unstaking Tokens:**

   - **Function:** `unstake(uint256 tokenID)`
   - **Description:** Allows users to unstake their DePIN tokens after the lock-up period.
   - **Example:**

   ```javascript
   await depinIndexToken.unstake(1); // Unstake DePIN tokens of type 1
   ```

#### **Query Functions:**

1. **Check User Stake:**

   - **Function:** `stakes(address user, uint256 tokenID)`
   - **Description:** Returns the amount staked by a user for a specific token.
   - **Example:**

   ```javascript
   const stakeAmount = await depinIndexToken.stakes("user_address", 1);
   console.log(stakeAmount.toString());
   ```

2. **Check Locked Until:**

   - **Function:** `lockedUntil(address user, uint256 tokenID)`
   - **Description:** Returns the timestamp until which the user's tokens are locked.
   - **Example:**

   ```javascript
   const lockTime = await depinIndexToken.lockedUntil("user_address", 1);
   console.log(lockTime.toString());
   ```

3. **Check Total Supply:**

   - **Function:** `totalSupply()`
   - **Description:** Returns the total supply of the rebased index token.
   - **Example:**

   ```javascript
   const totalSupply = await depinIndexToken.totalSupply();
   console.log(ethers.utils.formatEther(totalSupply));
   ```

### **4. Interacting via Web3 (JavaScript)**

To interact with the contract from a web application or script, you can use Web3.js or Ethers.js:

Find stake.html file, replace your contract and DePIN token addresses in the script.
