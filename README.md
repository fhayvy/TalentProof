# TalentProof

A reputation-based freelance network built on the Stacks blockchain that creates on-chain reputation for freelancers with peer jury dispute resolution.

## Overview

TalentProof addresses the trust problem in freelance marketplaces by creating immutable, portable reputation records that follow freelancers across platforms. Past work quality is permanently recorded on-chain, and disputes are resolved by peer juries who stake tokens to participate.

## Key Features

- **On-Chain Reputation**: Immutable reputation scores built from completed work history
- **Escrow System**: Automatic payment escrow with smart contract release
- **Peer Jury Resolution**: Community-driven dispute resolution with staked participation
- **Portable Profiles**: Reputation follows freelancers across any platform using TalentProof
- **Transparent Reviews**: Public review system for both clients and freelancers

## Smart Contract Functions

### Registration
- `register-freelancer()` - Create a freelancer profile
- `register-client()` - Create a client profile

### Job Management
- `create-job(freelancer, amount, description)` - Post new job with escrow
- `accept-job(job-id)` - Freelancer accepts posted job
- `complete-job(job-id)` - Client completes job and releases payment
- `submit-review(job-id, rating, review)` - Submit ratings and reviews

### Dispute Resolution
- `initiate-dispute(job-id, reason)` - Start dispute process
- `join-jury(dispute-id)` - Join jury panel (requires stake)
- `vote-on-dispute(dispute-id, vote-for-client)` - Cast jury vote

### Query Functions
- `get-freelancer-profile(principal)` - Get freelancer reputation data
- `get-client-profile(principal)` - Get client profile data
- `get-job-contract(job-id)` - Get job details
- `get-dispute(dispute-id)` - Get dispute information

## Reputation System

Freelancer reputation is calculated based on:
- Completed jobs (+5 points per completion)
- Won disputes (+10 points)
- Lost disputes (-15 points)
- Client ratings (integrated into overall score)

Starting reputation: 100 points

## Dispute Resolution Process

1. **Initiation**: Either party can initiate dispute during active job
2. **Jury Formation**: Up to 5 community members stake STX to join jury
3. **Voting Period**: 7-day window for jury to review and vote
4. **Resolution**: Majority vote determines outcome and fund distribution
5. **Rewards**: Winning voters receive proportional rewards from losing side stakes

## Technical Details

- **Blockchain**: Stacks (Bitcoin-secured)
- **Language**: Clarity smart contracts
- **Minimum Jury Stake**: 1 STX
- **Dispute Duration**: ~7 days (1008 blocks)
- **Jury Size**: 5 members maximum

## Getting Started

### Prerequisites
- Stacks wallet (Hiro, Xverse, etc.)
- STX tokens for transactions and jury participation

### Deployment
```bash
# Install Clarinet
npm install -g @hirosystems/clarinet-cli

# Initialize project
clarinet new talentproof
cd talentproof

# Add contract
cp talentproof.clar contracts/

# Test contracts
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

### Usage Example

```clarity
;; Register as freelancer
(contract-call? .talentproof register-freelancer)

;; Client creates job
(contract-call? .talentproof create-job 'SP1FREELANCER-ADDRESS u1000000 "Build landing page")

;; Freelancer accepts
(contract-call? .talentproof accept-job u1)

;; Client completes and releases payment
(contract-call? .talentproof complete-job u1)

;; Both parties submit reviews
(contract-call? .talentproof submit-review u1 u5 "Excellent work!")
```

## Roadmap

- **Phase 1**: Core contract deployment and testing
- **Phase 2**: Web interface development
- **Phase 3**: API integration for existing platforms
- **Phase 4**: Advanced reputation algorithms
- **Phase 5**: Cross-chain reputation bridging

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -m 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Open Pull Request

## Security Considerations

- All funds are held in contract escrow until job completion
- Jury members must stake tokens, creating economic incentive for honest voting
- Dispute resolution has time limits to prevent indefinite locks
- Reputation changes are permanent and cannot be manipulated

---

*Built with ❤️ on Stacks*