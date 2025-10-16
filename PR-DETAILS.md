# Blood Donation Tracking Smart Contract

## Overview
This PR introduces a comprehensive blockchain-based blood donation tracking system implemented as a Clarity v3 smart contract on the Stacks blockchain. The system enables secure, transparent tracking of blood donations from donor registration through inventory management, providing a complete end-to-end solution for blood banks and healthcare institutions.

## Technical Implementation

### Core Features
- **Donor Registration**: Secure registration system with blood type validation (O+, O-, A+, A-, B+, B-, AB+, AB-)
- **Donation Recording**: Track individual donations with quantity, timestamp, and automatic expiry calculation
- **Inventory Management**: Real-time blood inventory tracking with available and reserved quantities
- **Access Control**: Role-based permissions for contract owner and authorized hospitals
- **Eligibility Verification**: Automatic donor eligibility checking (56-day minimum interval between donations)

### Key Functions and Data Structures

#### Public Functions
- `register-donor(blood-type)`: Register new donors with blood type validation
- `record-donation(quantity-ml)`: Record blood donations with eligibility checks
- `approve-donation(donation-id)`: Approve tested donations for inventory inclusion
- `update-donation-status(donation-id, new-status)`: Update donation processing status
- `reserve-blood(blood-type, quantity-ml, hospital-address)`: Reserve blood for hospital use
- `authorize-hospital(hospital-address)`: Grant hospital permissions

#### Read-Only Functions
- `get-donor-info(donor-id)` & `get-donor-by-address(donor-address)`: Retrieve donor information
- `get-donation-info(donation-id)`: Access donation records
- `get-blood-inventory(blood-type)` & `get-total-inventory()`: Check blood availability
- `is-hospital-authorized(hospital-address)`: Verify hospital permissions
- `get-counters()`: System statistics

#### Data Structures
- **Donors Map**: Comprehensive donor profiles with donation history and eligibility
- **Donations Map**: Detailed donation records with status tracking and expiry
- **Blood Inventory Map**: Real-time inventory by blood type with available/reserved quantities
- **Authorization Maps**: Hospital permission management

### Error Handling
Implements comprehensive error constants including:
- `ERR-UNAUTHORIZED` (401): Permission violations
- `ERR-DONOR-NOT-FOUND` (404): Invalid donor references  
- `ERR-INVALID-BLOOD-TYPE` (406): Blood type validation failures
- `ERR-DONOR-NOT-ELIGIBLE` (407): Donation eligibility violations
- `ERR-INSUFFICIENT-INVENTORY` (408): Inventory shortage errors

## Testing & Validation

### ✅ Contract Validation
- Contract passes Clarity v3 syntax validation
- All npm tests successful with comprehensive test coverage
- CI/CD pipeline configured with GitHub Actions
- Line endings normalized for cross-platform compatibility

### Test Coverage
- Donor registration with valid/invalid blood types
- Donation recording with eligibility verification
- Access control and authorization testing
- Inventory management and tracking
- Error condition handling and edge cases

### CI/CD Integration
- GitHub Actions workflow for automated testing
- Docker-based Clarinet validation on every push
- Continuous integration ensures code quality

## Value Proposition
This smart contract provides:
1. **Transparency**: Immutable donation records on blockchain
2. **Security**: Cryptographic validation of all transactions
3. **Efficiency**: Automated eligibility and inventory management
4. **Traceability**: Complete audit trail from donation to usage
5. **Interoperability**: Standard Clarity v3 interface for integration