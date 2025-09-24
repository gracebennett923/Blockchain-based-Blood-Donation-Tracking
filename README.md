# 🩸 Blockchain-based Blood Donation Tracking

A comprehensive smart contract system built on Stacks blockchain for tracking blood donations, managing inventory, and facilitating blood requests between donors and hospitals.

## 🚀 Features

- 👥 **Donor Registration**: Register donors with blood type and personal information
- 🏥 **Hospital Management**: Verified hospital registration and management
- 💉 **Blood Donation Tracking**: Record and track all blood donations
- 📋 **Blood Inventory Management**: Real-time tracking of available blood units
- 🆘 **Blood Request System**: Hospitals can request specific blood types
- 🔄 **Request Fulfillment**: Match donations with hospital requests
- ⏰ **Expiration Tracking**: Monitor blood expiration dates
- 🩸 **Blood Type Compatibility**: Compatible donor matching system

## 📋 Contract Functions

### Donor Functions

#### `register-donor`
Register as a blood donor
```clarity
(register-donor "John Doe" "O+" u25)
```

#### `donate-blood`
Donate blood (donors can donate every 30 days)
```clarity
(donate-blood "O+" u1 "City Hospital")
```

### Hospital Functions

#### `register-hospital`
Register a hospital (owner only)
```clarity
(register-hospital "City General Hospital" "Downtown")
```

#### `request-blood`
Request blood units
```clarity
(request-blood "O+" u2 "urgent")
```

#### `fulfill-blood-request`
Fulfill a blood request with available donation
```clarity
(fulfill-blood-request u1 u5)
```

### Read-only Functions

#### `get-donor`
Get donor information
```clarity
(get-donor 'SP1ABC...)
```

#### `get-blood-inventory`
Check available blood units by type
```clarity
(get-blood-inventory "O+")
```

#### `get-donation`
Get donation details
```clarity
(get-donation u1)
```

#### `can-donate`
Check if donor is eligible to donate
```clarity
(can-donate 'SP1ABC...)
```

## 🩸 Supported Blood Types

- A+, A-, B+, B-, AB+, AB-, O+, O-

## ⚙️ Setup & Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js (for testing)

### Installation
```bash
git clone <repository-url>
cd Blockchain-based-Blood-Donation-Tracking
clarinet check
```

### Testing
```bash
npm install
npm test
```

### Deployment
```bash
clarinet deploy --testnet
```

## 🔒 Security Features

- ✅ Owner-only hospital registration
- ✅ Donor eligibility verification
- ✅ Blood expiration checking
- ✅ Input validation for blood types
- ✅ Donation frequency limits (30 days)

## 📊 Data Models

### Donor
- Name, blood type, age
- Last donation date, total donations
- Eligibility status

### Donation
- Donor, blood type, quantity
- Donation & expiry dates
- Location, usage status

### Hospital
- Name, location
- Verification status

### Blood Request
- Hospital, blood type, quantity
- Urgency level, fulfillment status

## 🎯 Usage Examples

### Complete Donation Flow
1. Register as donor: `(register-donor "Alice Smith" "A+" u28)`
2. Donate blood: `(donate-blood "A+" u1 "Medical Center")`
3. Hospital requests: `(request-blood "A+" u1 "normal")`
4. Fulfill request: `(fulfill-blood-request u1 u1)`

### Check Inventory
```clarity
(get-blood-inventory "A+")  ;; Returns available units
```

### Donor History
```clarity
(get-total-donations-by-donor 'SP1ABC...)  ;; Total donations count
```

## 🚦 Error Codes

- `u100`: Owner only
- `u101`: Not found
- `u102`: Already exists
- `u103`: Invalid blood type
- `u104`: Expired blood
- `u105`: Insufficient quantity
- `u106`: Unauthorized
- `u107`: Age requirement (18+)
- `u108`: Invalid quantity
- `u109`: Donor not eligible
- `u110`: Request already fulfilled
- `u111`: Donation already used
- `u112`: Blood type mismatch


## 📄 License

MIT License - see LICENSE file for details

---

Built with ❤️ on Stacks blockchain 🔗
