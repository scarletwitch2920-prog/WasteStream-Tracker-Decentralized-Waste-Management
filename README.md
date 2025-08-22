# ♻️ WasteStream Tracker: Decentralized Waste Management

Welcome to **WasteStream Tracker**, a Web3 platform built on the Stacks blockchain to revolutionize waste management and recycling. This project ensures transparent tracking of waste streams, incentivizes proper recycling with tokens, and empowers local cooperatives through a DAO to optimize operations and fund upcycling initiatives.

## ✨ Features

🔍 **Transparent Waste Tracking**: Immutable records of waste from generation to disposal, ensuring traceability for e-waste, plastics, and more.  
🎁 **Recycling Incentives**: Earn **WST tokens** for verified recycling actions, redeemable for local services or discounts.  
📜 **NFT Certification**: Certified recycled batches receive NFTs, proving compliance and enabling trade in secondary markets.  
🗳️ **DAO Governance**: Local waste cooperatives vote on collection routes, funding, and upcycling projects via a decentralized autonomous organization.  
✅ **Stakeholder Verification**: Regulators and auditors can access waste stream data for compliance checks.  
💸 **Fund Escrow**: Securely manage funds for upcycling initiatives, released based on DAO decisions.

## 🛠 How It Works

**For Waste Generators (Households/Businesses)**:  
- Register waste batches (e.g., e-waste, plastics) with a unique hash, type, and origin via the `WasteRegistry` contract.  
- Drop off waste at verified facilities and earn WST tokens through the `RecyclingVerification` contract.  

**For Recycling Facilities**:  
- Log waste handling steps in the `DisposalTracking` contract, ensuring transparency.  
- Issue NFTs for compliant recycled batches via the `NFTIssuer` contract.  

**For Cooperatives**:  
- Form a DAO using the `DAOGovernance` contract to vote on operational decisions like route optimization or funding upcycling projects.  
- Manage funds securely with the `FundEscrow` contract.  

**For Regulators/Auditors**:  
- Use the `StakeholderAccess` contract to verify waste stream data and ensure regulatory compliance.  

**Token Flow**:  
- WST tokens are minted by the `TokenMinting` contract and distributed to users for verified recycling actions.  
- Tokens can be redeemed with local partners or staked in the DAO for voting power.

## 📂 Smart Contracts

The platform leverages 8 Clarity smart contracts deployed on the Stacks blockchain:

1. **WasteRegistry**: Registers waste batches with a unique hash, type (e.g., e-waste, plastics), and metadata (origin, timestamp). Prevents duplicate registrations.  
2. **TokenMinting**: Mints and distributes WST tokens to reward recycling actions, with admin controls for supply management.  
3. **RecyclingVerification**: Verifies recycling actions via oracles or admin inputs, triggering token rewards from `TokenMinting`.  
4. **DisposalTracking**: Logs waste movement across facilities (e.g., collection, sorting, recycling), creating an immutable audit trail.  
5. **NFTIssuer**: Issues NFTs for certified recycled batches, storing metadata like material type and compliance status.  
6. **DAOGovernance**: Enables cooperative members to stake WST tokens and vote on proposals (e.g., route optimization, funding allocation).  
7. **FundEscrow**: Holds funds for upcycling projects, releasing them based on DAO-approved proposals.  
8. **StakeholderAccess**: Provides read-only access to waste stream data for regulators or auditors, with role-based permissions.

### Usage
- **Register Waste**: Call `WasteRegistry::register-waste` with a waste hash, type, and metadata.
- **Verify Recycling**: Facilities call `RecyclingVerification::verify-action` to confirm recycling and trigger token rewards.
- **Track Disposal**: Update waste movement in `DisposalTracking::log-transfer`.
- **Issue NFTs**: Facilities call `NFTIssuer::mint-nft` for certified batches.
- **DAO Voting**: Cooperative members stake tokens and submit proposals via `DAOGovernance::propose` and `DAOGovernance::vote`.
- **Fund Projects**: Use `FundEscrow::deposit` and `FundEscrow::release` for upcycling funds.
- **Verify Data**: Regulators call `StakeholderAccess::get-waste-details` for audits.

## 📜 Example Workflow
1. A household generates e-waste and hashes it (e.g., SHA-256 of device serials).
2. They register it via `WasteRegistry::register-waste` with type "e-waste" and origin metadata.
3. The waste is dropped at a facility, which logs sorting in `DisposalTracking::log-transfer`.
4. After recycling, the facility calls `RecyclingVerification::verify-action`, minting WST tokens to the household.
5. The recycled batch is certified, and `NFTIssuer::mint-nft` creates an NFT for trade or compliance.
6. The cooperative DAO votes on funding an upcycling project using `DAOGovernance::propose`, with funds managed by `FundEscrow`.
7. Regulators verify the entire process via `StakeholderAccess::get-waste-details`.

## 🔐 Security Considerations
- **Access Control**: Only authorized facilities can update `DisposalTracking` or issue NFTs.
- **Oracle Trust**: `RecyclingVerification` relies on trusted oracles or admins to prevent fraudulent reward claims.
- **DAO Fairness**: `DAOGovernance` uses weighted voting to prevent minority control.
- **Data Privacy**: Waste metadata is encrypted off-chain, with only hashes stored on-chain.
