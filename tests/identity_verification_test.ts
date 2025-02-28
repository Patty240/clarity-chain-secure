import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test enhanced identity verification workflow",
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
        
        // Update identity hash
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'update-identity-hash',
                [types.buff(Buffer.from('new-hash'))],
                user1.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Verify identity with cooldown
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'verify-identity',
                [types.principal(user1.address)],
                verifier1.address
            )
        ]);
        block.receipts[0].result.expectOk();
        
        // Try to verify again immediately (should fail)
        block = chain.mineBlock([
            Tx.contractCall(
                'identity_verification',
                'verify-identity',
                [types.principal(user1.address)],
                verifier1.address
            )
        ]);
        block.receipts[0].result.expectErr(106); // err-cooldown-active
        
        // Mine blocks to pass cooldown
        chain.mineEmptyBlockUntil(chain.blockHeight + 7);
        
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
        
        // Check verified status
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
