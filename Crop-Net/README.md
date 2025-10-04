# AgriChain Tracker

## Overview

AgriChain Tracker is a decentralized blockchain solution built on Clarity smart contracts for managing agricultural supply chains. The system provides complete transparency and traceability of agricultural products from farm to consumer, ensuring quality verification and maintaining a comprehensive ownership history throughout the supply chain.

## Features

- Participant registration and management with role-based access
- Product registration and tracking throughout the supply chain
- Quality assessment and automatic certification
- Ownership transfer with complete audit trails
- Geographic location tracking
- Supply chain stage management
- Complete event history for all products
- Reputation scoring for participants

## Contract Constants

### Error Codes

- `ERR-UNAUTHORIZED-ACCESS (u1)` - Caller lacks required permissions
- `ERR-PRODUCT-NOT-FOUND (u2)` - Product ID does not exist in registry
- `ERR-INVALID-STATUS-TRANSITION (u3)` - Invalid supply chain stage transition
- `ERR-DUPLICATE-RECORD (u4)` - Record already exists
- `ERR-INVALID-INPUT-DATA (u5)` - Input validation failed

### Configuration

- `contract-administrator` - Set to deployer address at deployment
- `quality-certification-threshold` - Minimum quality score for certification (default: 60/100)

## Data Structures

### Supply Chain Participants

Stores information about all registered participants in the supply chain network.

**Fields:**
- `role-type` - Participant's role (max 20 characters)
- `is-active-status` - Whether participant can perform operations
- `reputation-score` - Participant's reputation (0-100+)

### Product Registry

Maintains complete product information and current status.

**Fields:**
- `name-of-product` - Product name (max 50 characters)
- `original-producer` - Address of the original producer
- `current-owner` - Current owner's address
- `current-stage` - Current supply chain stage (max 20 characters)
- `quality-score` - Quality assessment score (0-100)
- `timestamp-registered` - Block height when registered
- `current-location` - Current geographic location (max 100 characters)
- `price-value` - Current price value
- `is-quality-certified` - Whether product meets quality threshold

### Product Event History

Records all supply chain events for complete traceability.

**Fields:**
- `from-participant` - Event initiator address
- `to-participant` - Event recipient address
- `event-category` - Type of event (max 20 characters)
- `timestamp-occurred` - Block height when event occurred
- `event-details` - Event description (max 200 characters)

## Read-Only Functions

### fetch-product-details

Retrieves complete product information from the registry.

**Parameters:**
- `product-id` (uint) - Unique product identifier

**Returns:** Optional product data tuple

### fetch-participant-info

Retrieves participant information and credentials.

**Parameters:**
- `participant-address` (principal) - Participant's blockchain address

**Returns:** Optional participant data tuple

### fetch-event-record

Retrieves a specific event from a product's supply chain history.

**Parameters:**
- `product-id` (uint) - Product identifier
- `event-id` (uint) - Event identifier

**Returns:** Optional event data tuple

## Public Functions

### add-supply-chain-participant

Registers a new participant in the supply chain network. Only callable by contract administrator.

**Parameters:**
- `participant-address` (principal) - Address to register
- `role-type` (string-ascii 20) - Participant's role in supply chain

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller is not administrator
- `ERR-DUPLICATE-RECORD` - Participant already registered
- `ERR-INVALID-INPUT-DATA` - Invalid role type format

### modify-participant-status

Updates participant active status to enable or disable access. Only callable by contract administrator.

**Parameters:**
- `participant-address` (principal) - Participant to modify
- `new-active-status` (bool) - New status (true = active, false = inactive)

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller is not administrator or participant not found

### create-product-record

Registers a new agricultural product into the supply chain with the caller as the original producer and initial owner.

**Parameters:**
- `product-id` (uint) - Unique product identifier
- `name-of-product` (string-ascii 50) - Product name
- `origin-location` (string-ascii 100) - Initial location
- `initial-price-value` (uint) - Initial price

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller is not an active participant
- `ERR-DUPLICATE-RECORD` - Product ID already exists
- `ERR-INVALID-INPUT-DATA` - Invalid input format or values

### advance-product-stage

Updates the current stage of a product in the supply chain and records the transition as an event.

**Parameters:**
- `product-id` (uint) - Product to update
- `next-stage` (string-ascii 20) - New supply chain stage
- `stage-description` (string-ascii 200) - Description of stage transition

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller is not active or not current owner
- `ERR-PRODUCT-NOT-FOUND` - Product does not exist
- `ERR-INVALID-INPUT-DATA` - Invalid input format

### execute-ownership-transfer

Transfers ownership of a product to another supply chain participant and records the transfer event.

**Parameters:**
- `product-id` (uint) - Product to transfer
- `recipient-address` (principal) - New owner address
- `transfer-description` (string-ascii 200) - Transfer details

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller or recipient not active, or caller not current owner
- `ERR-PRODUCT-NOT-FOUND` - Product does not exist
- `ERR-INVALID-INPUT-DATA` - Invalid input format

### record-quality-inspection

Records quality assessment results for a product and automatically updates certification status based on the quality threshold.

**Parameters:**
- `product-id` (uint) - Product to assess
- `assessed-quality-score` (uint) - Quality score (0-100)
- `inspection-notes` (string-ascii 200) - Inspection details

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller is not an active participant
- `ERR-PRODUCT-NOT-FOUND` - Product does not exist
- `ERR-INVALID-INPUT-DATA` - Invalid score (over 100) or format

### update-geographic-location

Updates the geographic location of a product and tracks movement throughout the supply chain.

**Parameters:**
- `product-id` (uint) - Product to update
- `updated-location` (string-ascii 100) - New location
- `location-notes` (string-ascii 200) - Location update details

**Returns:** `(ok true)` on success

**Errors:**
- `ERR-UNAUTHORIZED-ACCESS` - Caller is not active or not current owner
- `ERR-PRODUCT-NOT-FOUND` - Product does not exist
- `ERR-INVALID-INPUT-DATA` - Invalid input format

## Deployment

1. Deploy the contract to the Stacks blockchain
2. The deployer becomes the contract administrator
3. Register supply chain participants using `add-supply-chain-participant`
4. Participants can begin registering products and performing operations

## Usage Example

```clarity
;; Administrator registers a farmer
(contract-call? .agrichain-tracker add-supply-chain-participant 'ST1FARMER... "farmer")

;; Farmer registers a product
(contract-call? .agrichain-tracker create-product-record 
    u1 
    "Organic Tomatoes" 
    "Farm Location, Region" 
    u1000)

;; Farmer advances product stage
(contract-call? .agrichain-tracker advance-product-stage 
    u1 
    "harvested" 
    "Harvested 500kg of organic tomatoes")

;; Quality inspector performs assessment
(contract-call? .agrichain-tracker record-quality-inspection 
    u1 
    u85 
    "Excellent quality, meets organic standards")

;; Farmer transfers to distributor
(contract-call? .agrichain-tracker execute-ownership-transfer 
    u1 
    'ST1DISTRIBUTOR... 
    "Transferred to XYZ Distribution")

;; Distributor updates location
(contract-call? .agrichain-tracker update-geographic-location 
    u1 
    "Distribution Center, City" 
    "Arrived at distribution center")
```

## Security Considerations

- Only the contract administrator can register and manage participants
- Only active participants can perform supply chain operations
- Only current product owners can transfer ownership or update product information
- All operations are recorded with timestamps for complete audit trails
- Input validation prevents invalid data entry
- Quality certification is automatically determined based on objective thresholds