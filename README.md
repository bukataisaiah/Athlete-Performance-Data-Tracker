# StatChain ⛓️🏅

> **An immutable ledger for tracking and verifying professional athlete performance statistics**

## Overview 📊

StatChain is a blockchain-based athlete performance tracking system built on Stacks using Clarity smart contracts. It provides tamper-proof recording and verification of athletic performance data with multi-level authorization controls.

### Key Features 🌟

- 🔐 **Immutable Performance Records** - Once recorded, stats can't be altered
- ✅ **Multi-Level Verification** - Authorized scorers can verify performance data
- 🏆 **Season Management** - Create and manage athletic seasons with defined timeframes
- 👤 **Athlete Registry** - Secure athlete registration with unique identifiers
- 📈 **Aggregate Statistics** - Automatic calculation of seasonal totals
- 🛡️ **Access Control** - Role-based permissions for data recording and verification

## Contract Architecture 🏗️

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Athlete        │    │  Season         │    │  Performance    │
│  Registry       │    │  Manager        │    │  Tracker        │
│                 │    │                 │    │                 │
│ • Registration  │────│ • Create Season │────│ • Record Stats  │
│ • Profile Mgmt  │    │ • Close Season  │    │ • Verification  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Authorization  │
                    │  System         │
                    │                 │
                    │ • Owner Control │
                    │ • Scorer Perms  │
                    └─────────────────┘
```

## Setup & Installation 🚀

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) (latest version)
- [Node.js](https://nodejs.org/) (v16 or higher)
- Clarity v3 support

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/StatChain.git
   cd StatChain
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Check contract syntax:**
   ```bash
   clarinet check
   ```

4. **Run tests:**
   ```bash
   clarinet test
   ```

5. **Deploy to devnet:**
   ```bash
   clarinet deploy --devnet
   ```

## Contract Functions 📋

### Public Functions (State-Changing)

#### `register-athlete`
**Purpose:** Register a new athlete in the system  
**Caller:** Any principal (becomes the athlete's account)  
**Parameters:**
- `name` (string-ascii 50): Athlete's full name
- `sport` (string-ascii 20): Sport they play
- `team` (string-ascii 30): Current team
- `position` (string-ascii 20): Playing position

**Returns:** `(ok athlete-id)` or error

```clarity
(contract-call? .StatChain register-athlete "John Smith" "Basketball" "Lakers" "Point Guard")
```

#### `create-season`
**Purpose:** Create a new athletic season  
**Caller:** Contract owner only  
**Parameters:**
- `name` (string-ascii 30): Season name
- `sport` (string-ascii 20): Sport type
- `duration-blocks` (uint): Season length in blocks

**Returns:** `(ok season-id)` or error

```clarity
(contract-call? .StatChain create-season "2024 NBA Regular Season" "Basketball" u144000)
```

#### `add-authorized-scorer`
**Purpose:** Grant scoring permissions to a principal  
**Caller:** Contract owner only  
**Parameters:**
- `scorer` (principal): Address to authorize

```clarity
(contract-call? .StatChain add-authorized-scorer 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

#### `record-performance`
**Purpose:** Record athlete performance data for a game  
**Caller:** Authorized scorer or contract owner  
**Parameters:**
- `athlete-id` (uint): Registered athlete ID
- `season-id` (uint): Active season ID
- `opponent` (string-ascii 30): Opposing team
- `goals` (uint): Goals scored
- `assists` (uint): Assists made
- `points` (uint): Total points
- `games-played` (uint): Games in this record (usually 1)
- `minutes-played` (uint): Minutes played

**Returns:** `(ok performance-id)` or error

```clarity
(contract-call? .StatChain record-performance u1 u1 "Celtics" u2 u3 u5 u1 u42)
```

#### `verify-performance`
**Purpose:** Verify a recorded performance as accurate  
**Caller:** Authorized scorer or contract owner  
**Parameters:**
- `performance-id` (uint): Performance record to verify

```clarity
(contract-call? .StatChain verify-performance u1)
```

#### `update-athlete-info`
**Purpose:** Update athlete profile information  
**Caller:** The athlete (registered principal)  
**Parameters:**
- `name` (string-ascii 50): Updated name
- `team` (string-ascii 30): Updated team
- `position` (string-ascii 20): Updated position

```clarity
(contract-call? .StatChain update-athlete-info "John Smith Jr." "Warriors" "Shooting Guard")
```

### Read-Only Functions (Query)

#### `get-athlete`
**Purpose:** Retrieve athlete information by ID
```clarity
(contract-call? .StatChain get-athlete u1)
```

#### `get-season-stats`
**Purpose:** Get aggregate season statistics for an athlete
```clarity
(contract-call? .StatChain get-season-stats u1 u1)
```

#### `get-performance`
**Purpose:** Retrieve specific performance record
```clarity
(contract-call? .StatChain get-performance u1)
```

#### `is-season-active`
**Purpose:** Check if a season is currently active
```clarity
(contract-call? .StatChain is-season-active u1)
```

## Usage Examples 💡

### Complete Workflow Example

1. **Register an athlete:**
```bash
clarinet console
::set_tx_sender ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE
(contract-call? .StatChain register-athlete "Michael Jordan" "Basketball" "Bulls" "Shooting Guard")
```

2. **Create a season (as owner):**
```bash
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
(contract-call? .StatChain create-season "1996 NBA Finals" "Basketball" u1000)
```

3. **Add an authorized scorer:**
```bash
(contract-call? .StatChain add-authorized-scorer ST2HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

4. **Record a performance:**
```bash
::set_tx_sender ST2HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE
(contract-call? .StatChain record-performance u1 u1 "Lakers" u45 u8 u53 u1 u48)
```

5. **Verify the performance:**
```bash
(contract-call? .StatChain verify-performance u1)
```

6. **Query season statistics:**
```bash
(contract-call? .StatChain get-season-stats u1 u1)
```

## Error Codes 🚨

| Code | Name | Description |
|------|------|-------------|
| `u1001` | `ERR-NOT-AUTHORIZED` | Caller lacks required permissions |
| `u1002` | `ERR-ATHLETE-NOT-FOUND` | Athlete ID doesn't exist |
| `u1003` | `ERR-SEASON-NOT-FOUND` | Season ID doesn't exist |
| `u1004` | `ERR-SEASON-CLOSED` | Season is not active |
| `u1005` | `ERR-ALREADY-VERIFIED` | Performance already verified |
| `u1006` | `ERR-INVALID-STATS` | Invalid statistical data |
| `u1007` | `ERR-SEASON-ACTIVE` | Cannot modify active season |
| `u1008` | `ERR-ATHLETE-EXISTS` | Principal already registered |
| `u1009` | `ERR-PERFORMANCE-NOT-FOUND` | Performance record doesn't exist |
| `u1010` | `ERR-INVALID-SEASON` | Season parameters invalid |

## Data Storage 💾

The contract maintains several data maps:

- **`athletes`**: Core athlete profiles
- **`seasons`**: Season definitions and status
- **`performances`**: Individual game performances
- **`season-stats`**: Aggregated seasonal statistics
- **`authorized-scorers`**: Principals with scoring permissions
- **`athlete-season-performances`**: Performance ID lists per athlete/season

## Testing 🧪

Run the test suite:
```bash
npm test
# or
clarinet test
```

Test individual functions in the console:
```bash
clarinet console
```

## Deployment 🌐

### Testnet Deployment
```bash
clarinet deploy --testnet
```

### Mainnet Deployment
```bash
clarinet deploy --mainnet
```

## Contributing 🤝

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security Considerations 🔒

- Only contract owner can create seasons and authorize scorers
- Athletes can only update their own information
- Performance verification requires authorized scorer privileges
- All data is immutable once recorded (except verification status)
- Season closure is permanent and irreversible

## License 📄

This project is licensed under the MIT License - see the LICENSE file for details.

## Support 💬

For questions and support, please open an issue on GitHub or contact the development team.

---

**Built with ❤️ using Stacks and Clarity**
