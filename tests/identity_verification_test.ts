import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test identity registration and verification workflow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        const verifier = accounts.get('wallet_2')!;
        
        // Test identity registration
        let block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'register-identity',
                [types.buff(Buffer.from('test-hash'))],
                user1.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Add verifier
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'add-verifier',
                [types.principal(verifier.address)],
                deployer.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Verify identity
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'verify-identity',
                [types.principal(user1.address)],
                verifier.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Check verification status
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'is-identity-verified',
                [types.principal(user1.address)],
                user1.address
            )
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
    }
});

Clarinet.test({
    name: "Test unauthorized operations",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        const user2 = accounts.get('wallet_2')!;
        
        // Unauthorized verifier attempt
        let block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'verify-identity',
                [types.principal(user1.address)],
                user2.address
            )
        ]);
        block.receipts[0].result.expectErr(types.uint(103)); // err-unauthorized
        
        // Unauthorized verifier addition
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'add-verifier',
                [types.principal(user2.address)],
                user1.address
            )
        ]);
        block.receipts[0].result.expectErr(types.uint(100)); // err-owner-only
    }
});