import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test identity registration and multi-factor verification workflow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        const verifier1 = accounts.get('wallet_2')!;
        const verifier2 = accounts.get('wallet_3')!;
        
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
        
        // Add verifiers
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'add-verifier',
                [types.principal(verifier1.address)],
                deployer.address
            ),
            Tx.contractCall(
                'identity_verification',
                'add-verifier',
                [types.principal(verifier2.address)],
                deployer.address
            )
        ]);
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        // First verification
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'verify-identity',
                [types.principal(user1.address)],
                verifier1.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Check verification count
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'get-verification-count',
                [types.principal(user1.address)],
                user1.address
            )
        ]);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        
        // Check not verified yet
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'is-identity-verified',
                [types.principal(user1.address)],
                user1.address
            )
        ]);
        assertEquals(block.receipts[0].result.expectOk(), false);
        
        // Second verification
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'verify-identity',
                [types.principal(user1.address)],
                verifier2.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Check now verified
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
