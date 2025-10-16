import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can register a new donor with valid blood type",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const donor1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [
                types.uint(1) // O+ blood type
            ], donor1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Verify donor was registered
        let getDonor = chain.callReadOnlyFn('blood-donation-tracker', 'get-donor-by-address', [
            types.principal(donor1.address)
        ], deployer.address);
        
        let donorInfo = getDonor.result.expectSome().expectTuple();
        assertEquals(donorInfo['blood-type'], types.uint(1));
        assertEquals(donorInfo['donor-address'], types.principal(donor1.address));
        assertEquals(donorInfo['total-donations'], types.uint(0));
        assertEquals(donorInfo['is-eligible'], types.bool(true));
    },
});

Clarinet.test({
    name: "Cannot register donor with invalid blood type",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const donor1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [
                types.uint(9) // Invalid blood type
            ], donor1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(406); // ERR-INVALID-BLOOD-TYPE
    },
});

Clarinet.test({
    name: "Cannot register same donor twice",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const donor1 = accounts.get('wallet_1')!;
        
        // First registration should succeed
        let block1 = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [
                types.uint(2) // O- blood type
            ], donor1.address)
        ]);
        block1.receipts[0].result.expectOk().expectUint(1);
        
        // Second registration should fail
        let block2 = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [
                types.uint(3) // A+ blood type
            ], donor1.address)
        ]);
        block2.receipts[0].result.expectErr().expectUint(401); // ERR-UNAUTHORIZED
    },
});

Clarinet.test({
    name: "Registered donor can record donation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const donor1 = accounts.get('wallet_1')!;
        
        // Register donor first
        let registerBlock = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [
                types.uint(1) // O+ blood type
            ], donor1.address)
        ]);
        registerBlock.receipts[0].result.expectOk().expectUint(1);
        
        // Record donation
        let donationBlock = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'record-donation', [
                types.uint(450) // 450ml donation
            ], donor1.address)
        ]);
        donationBlock.receipts[0].result.expectOk().expectUint(1);
        
        // Verify donation was recorded
        let getDonation = chain.callReadOnlyFn('blood-donation-tracker', 'get-donation-info', [
            types.uint(1)
        ], deployer.address);
        
        let donationInfo = getDonation.result.expectSome().expectTuple();
        assertEquals(donationInfo['donor-id'], types.uint(1));
        assertEquals(donationInfo['blood-type'], types.uint(1));
        assertEquals(donationInfo['quantity-ml'], types.uint(450));
        assertEquals(donationInfo['status'], types.uint(1)); // STATUS-COLLECTED
    },
});

Clarinet.test({
    name: "Unregistered donor cannot record donation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const donor1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'record-donation', [
                types.uint(450)
            ], donor1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(404); // ERR-DONOR-NOT-FOUND
    },
});

Clarinet.test({
    name: "Cannot record donation with zero quantity",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const donor1 = accounts.get('wallet_1')!;
        
        // Register donor first
        let registerBlock = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [
                types.uint(1)
            ], donor1.address)
        ]);
        registerBlock.receipts[0].result.expectOk();
        
        // Try to record zero quantity donation
        let donationBlock = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'record-donation', [
                types.uint(0)
            ], donor1.address)
        ]);
        
        donationBlock.receipts[0].result.expectErr().expectUint(409); // ERR-INVALID-QUANTITY
    },
});

Clarinet.test({
    name: "Can get blood inventory for specific type",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let getInventory = chain.callReadOnlyFn('blood-donation-tracker', 'get-blood-inventory', [
            types.uint(1) // O+ blood type
        ], deployer.address);
        
        let inventory = getInventory.result.expectSome().expectTuple();
        assertEquals(inventory['available-ml'], types.uint(0));
        assertEquals(inventory['reserved-ml'], types.uint(0));
    },
});

Clarinet.test({
    name: "Can get total inventory",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let getTotalInventory = chain.callReadOnlyFn('blood-donation-tracker', 'get-total-inventory', [], deployer.address);
        
        let totalInventory = getTotalInventory.result.expectTuple();
        assertEquals(totalInventory['total-available-ml'], types.uint(0));
        assertEquals(totalInventory['total-reserved-ml'], types.uint(0));
    },
});

Clarinet.test({
    name: "Can get counters",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const donor1 = accounts.get('wallet_1')!;
        
        // Initially counters should be zero
        let initialCounters = chain.callReadOnlyFn('blood-donation-tracker', 'get-counters', [], deployer.address);
        let counters = initialCounters.result.expectTuple();
        assertEquals(counters['total-donors'], types.uint(0));
        assertEquals(counters['total-donations'], types.uint(0));
        
        // Register donor
        chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [types.uint(1)], donor1.address)
        ]);
        
        // Record donation
        chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'record-donation', [types.uint(450)], donor1.address)
        ]);
        
        // Check updated counters
        let updatedCounters = chain.callReadOnlyFn('blood-donation-tracker', 'get-counters', [], deployer.address);
        let newCounters = updatedCounters.result.expectTuple();
        assertEquals(newCounters['total-donors'], types.uint(1));
        assertEquals(newCounters['total-donations'], types.uint(1));
    },
});

Clarinet.test({
    name: "Only contract owner can update donation status",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const donor1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Setup: Register donor and record donation
        chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'register-donor', [types.uint(1)], donor1.address),
            Tx.contractCall('blood-donation-tracker', 'record-donation', [types.uint(450)], donor1.address)
        ]);
        
        // Non-owner cannot update status
        let unauthorizedUpdate = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'update-donation-status', [
                types.uint(1),
                types.uint(2) // STATUS-TESTED
            ], wallet2.address)
        ]);
        unauthorizedUpdate.receipts[0].result.expectErr().expectUint(401); // ERR-UNAUTHORIZED
        
        // Owner can update status
        let authorizedUpdate = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'update-donation-status', [
                types.uint(1),
                types.uint(2) // STATUS-TESTED
            ], deployer.address)
        ]);
        authorizedUpdate.receipts[0].result.expectOk().expectBool(true);
    },
});

Clarinet.test({
    name: "Only contract owner can authorize hospitals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const hospital = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Non-owner cannot authorize hospital
        let unauthorizedAuth = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'authorize-hospital', [
                types.principal(hospital.address)
            ], wallet2.address)
        ]);
        unauthorizedAuth.receipts[0].result.expectErr().expectUint(401); // ERR-UNAUTHORIZED
        
        // Owner can authorize hospital
        let authorizedAuth = chain.mineBlock([
            Tx.contractCall('blood-donation-tracker', 'authorize-hospital', [
                types.principal(hospital.address)
            ], deployer.address)
        ]);
        authorizedAuth.receipts[0].result.expectOk().expectBool(true);
        
        // Verify hospital is authorized
        let isAuthorized = chain.callReadOnlyFn('blood-donation-tracker', 'is-hospital-authorized', [
            types.principal(hospital.address)
        ], deployer.address);
        isAuthorized.result.expectBool(true);
    },
});