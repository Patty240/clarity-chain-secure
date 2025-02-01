# ChainSecure
A blockchain-powered identity verification platform built on Stacks.

This contract implements a decentralized identity verification system with the following features:
- Identity registration with unique identifiers
- Multi-factor identity verification requiring approval from multiple authorized verifiers
- Verification tracking and status monitoring
- Revocation capabilities
- Identity status checking

## Multi-Factor Verification
The system now requires multiple independent verifiers to approve an identity before it is considered fully verified. This enhances security and reduces the risk of compromised verifier accounts.

Key features:
- Configurable number of required verifications (default: 2)
- Tracking of individual verifier approvals
- Prevention of duplicate verifications
- Status monitoring of verification progress
