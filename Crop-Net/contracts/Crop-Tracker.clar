;; AgriChain Tracker - Decentralized Agricultural Supply Chain Management
;; A comprehensive blockchain solution for tracking agricultural products from farm to consumer,
;; ensuring transparency, quality verification, and complete ownership history throughout the supply chain.

;; Error codes for contract operations
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-PRODUCT-NOT-FOUND (err u2))
(define-constant ERR-INVALID-STATUS-TRANSITION (err u3))
(define-constant ERR-DUPLICATE-RECORD (err u4))
(define-constant ERR-INVALID-INPUT-DATA (err u5))

;; Contract administrator set at deployment
(define-constant contract-administrator tx-sender)

;; Minimum quality score required for certification (out of 100)
(define-data-var quality-certification-threshold uint u60)

;; Counter for generating unique event identifiers across the supply chain
(define-data-var supply-chain-event-counter uint u0)

;; Registry of all participants in the agricultural supply chain
;; Maps participant addresses to their role, status, and reputation metrics
(define-map supply-chain-participants
    principal
    {
        role-type: (string-ascii 20),
        is-active-status: bool,
        reputation-score: uint
    }
)

;; Complete product inventory with current status and metadata
;; Tracks all agricultural products registered in the supply chain
(define-map product-registry
    uint
    {
        name-of-product: (string-ascii 50),
        original-producer: principal,
        current-owner: principal,
        current-stage: (string-ascii 20),
        quality-score: uint,
        timestamp-registered: uint,
        current-location: (string-ascii 100),
        price-value: uint,
        is-quality-certified: bool
    }
)

;; Historical record of all supply chain events for each product
;; Provides complete audit trail and traceability
(define-map product-event-history
    {product-id: uint, event-id: uint}
    {
        from-participant: principal,
        to-participant: principal,
        event-category: (string-ascii 20),
        timestamp-occurred: uint,
        event-details: (string-ascii 200)
    }
)

;; Retrieves complete product information from the registry
(define-read-only (fetch-product-details (product-id uint))
    (map-get? product-registry product-id)
)

;; Retrieves participant information and credentials
(define-read-only (fetch-participant-info (participant-address principal))
    (map-get? supply-chain-participants participant-address)
)

;; Retrieves specific event from product's supply chain history
(define-read-only (fetch-event-record (product-id uint) (event-id uint))
    (map-get? product-event-history {product-id: product-id, event-id: event-id})
)

;; Checks if a participant is registered and active in the system
(define-private (verify-participant-active (participant-address principal))
    (let ((participant-data (unwrap! (map-get? supply-chain-participants participant-address) false)))
        (get is-active-status participant-data)
    )
)

;; Generates a unique sequential identifier for supply chain events
(define-private (create-next-event-id)
    (begin
        (var-set supply-chain-event-counter (+ (var-get supply-chain-event-counter) u1))
        (var-get supply-chain-event-counter)
    )
)

;; Validates short text fields (role types, stages)
(define-private (check-short-string-valid (text-input (string-ascii 20)))
    (and (>= (len text-input) u1) (<= (len text-input) u20))
)

;; Validates medium text fields (product names)
(define-private (check-medium-string-valid (text-input (string-ascii 50)))
    (and (>= (len text-input) u1) (<= (len text-input) u50))
)

;; Validates location text fields
(define-private (check-location-string-valid (text-input (string-ascii 100)))
    (and (>= (len text-input) u1) (<= (len text-input) u100))
)

;; Validates description text fields (event details, notes)
(define-private (check-description-string-valid (text-input (string-ascii 200)))
    (and (>= (len text-input) u1) (<= (len text-input) u200))
)

;; Validates unsigned integer values are within acceptable range
(define-private (check-uint-within-bounds (value-to-check uint))
    (< value-to-check u340282366920938463463374607431768211455)
)

;; Registers a new participant in the supply chain network
;; Only contract administrator can register participants
(define-public (add-supply-chain-participant (participant-address principal) (role-type (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none (map-get? supply-chain-participants participant-address)) ERR-DUPLICATE-RECORD)
        (asserts! (check-short-string-valid role-type) ERR-INVALID-INPUT-DATA)
        (ok (map-set supply-chain-participants 
            participant-address
            {
                role-type: role-type,
                is-active-status: true,
                reputation-score: u100
            }
        ))
    )
)

;; Updates participant active status (enable/disable access)
;; Only contract administrator can modify participant status
(define-public (modify-participant-status (participant-address principal) (new-active-status bool))
    (begin
        (asserts! (is-eq tx-sender contract-administrator) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-some (map-get? supply-chain-participants participant-address)) ERR-UNAUTHORIZED-ACCESS)
        (ok (map-set supply-chain-participants 
            participant-address
            (merge (unwrap-panic (map-get? supply-chain-participants participant-address))
                  {is-active-status: new-active-status})
        ))
    )
)

;; Registers a new agricultural product into the supply chain
;; Creates initial product record with producer as current owner
(define-public (create-product-record 
    (product-id uint)
    (name-of-product (string-ascii 50))
    (origin-location (string-ascii 100))
    (initial-price-value uint))
    (let ((producer-address tx-sender))
        (begin
            (asserts! (verify-participant-active producer-address) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-none (map-get? product-registry product-id)) ERR-DUPLICATE-RECORD)
            (asserts! (check-uint-within-bounds product-id) ERR-INVALID-INPUT-DATA)
            (asserts! (check-medium-string-valid name-of-product) ERR-INVALID-INPUT-DATA)
            (asserts! (check-location-string-valid origin-location) ERR-INVALID-INPUT-DATA)
            (asserts! (check-uint-within-bounds initial-price-value) ERR-INVALID-INPUT-DATA)
            (ok (map-set product-registry
                product-id
                {
                    name-of-product: name-of-product,
                    original-producer: producer-address,
                    current-owner: producer-address,
                    current-stage: "registered",
                    quality-score: u100,
                    timestamp-registered: block-height,
                    current-location: origin-location,
                    price-value: initial-price-value,
                    is-quality-certified: false
                }
            ))
        )
    )
)

;; Updates the current stage of a product in the supply chain
;; Records stage transition as an event in product history
(define-public (advance-product-stage 
    (product-id uint)
    (next-stage (string-ascii 20))
    (stage-description (string-ascii 200)))
    (let (
        (current-participant tx-sender)
        (product-data (unwrap! (map-get? product-registry product-id) ERR-PRODUCT-NOT-FOUND))
        )
        (begin
            (asserts! (verify-participant-active current-participant) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-eq (get current-owner product-data) current-participant) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (check-uint-within-bounds product-id) ERR-INVALID-INPUT-DATA)
            (asserts! (check-short-string-valid next-stage) ERR-INVALID-INPUT-DATA)
            (asserts! (check-description-string-valid stage-description) ERR-INVALID-INPUT-DATA)
            (map-set product-registry
                product-id
                (merge product-data {current-stage: next-stage})
            )
            (map-set product-event-history
                {product-id: product-id, event-id: (create-next-event-id)}
                {
                    from-participant: current-participant,
                    to-participant: current-participant,
                    event-category: next-stage,
                    timestamp-occurred: block-height,
                    event-details: stage-description
                }
            )
            (ok true)
        )
    )
)

;; Transfers ownership of a product to another supply chain participant
;; Records transfer event with complete details for audit trail
(define-public (execute-ownership-transfer
    (product-id uint)
    (recipient-address principal)
    (transfer-description (string-ascii 200)))
    (let (
        (sender-address tx-sender)
        (product-data (unwrap! (map-get? product-registry product-id) ERR-PRODUCT-NOT-FOUND))
        )
        (begin
            (asserts! (verify-participant-active sender-address) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (verify-participant-active recipient-address) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-eq (get current-owner product-data) sender-address) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (check-uint-within-bounds product-id) ERR-INVALID-INPUT-DATA)
            (asserts! (check-description-string-valid transfer-description) ERR-INVALID-INPUT-DATA)
            (map-set product-registry
                product-id
                (merge product-data {
                    current-owner: recipient-address,
                    current-stage: "transferred"
                })
            )
            (map-set product-event-history
                {product-id: product-id, event-id: (create-next-event-id)}
                {
                    from-participant: sender-address,
                    to-participant: recipient-address,
                    event-category: "transfer",
                    timestamp-occurred: block-height,
                    event-details: transfer-description
                }
            )
            (ok true)
        )
    )
)

;; Records quality assessment results for a product
;; Automatically updates certification status based on threshold
(define-public (record-quality-inspection
    (product-id uint)
    (assessed-quality-score uint)
    (inspection-notes (string-ascii 200)))
    (let (
        (inspector-address tx-sender)
        (product-data (unwrap! (map-get? product-registry product-id) ERR-PRODUCT-NOT-FOUND))
        )
        (begin
            (asserts! (verify-participant-active inspector-address) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (check-uint-within-bounds product-id) ERR-INVALID-INPUT-DATA)
            (asserts! (<= assessed-quality-score u100) ERR-INVALID-INPUT-DATA)
            (asserts! (check-description-string-valid inspection-notes) ERR-INVALID-INPUT-DATA)
            (map-set product-registry
                product-id
                (merge product-data {
                    quality-score: assessed-quality-score,
                    is-quality-certified: (>= assessed-quality-score (var-get quality-certification-threshold))
                })
            )
            (map-set product-event-history
                {product-id: product-id, event-id: (create-next-event-id)}
                {
                    from-participant: inspector-address,
                    to-participant: inspector-address,
                    event-category: "quality-assessment",
                    timestamp-occurred: block-height,
                    event-details: inspection-notes
                }
            )
            (ok true)
        )
    )
)

;; Updates the geographic location of a product
;; Tracks product movement throughout the supply chain
(define-public (update-geographic-location
    (product-id uint)
    (updated-location (string-ascii 100))
    (location-notes (string-ascii 200)))
    (let (
        (responsible-participant tx-sender)
        (product-data (unwrap! (map-get? product-registry product-id) ERR-PRODUCT-NOT-FOUND))
        )
        (begin
            (asserts! (verify-participant-active responsible-participant) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (is-eq (get current-owner product-data) responsible-participant) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (check-uint-within-bounds product-id) ERR-INVALID-INPUT-DATA)
            (asserts! (check-location-string-valid updated-location) ERR-INVALID-INPUT-DATA)
            (asserts! (check-description-string-valid location-notes) ERR-INVALID-INPUT-DATA)
            (map-set product-registry
                product-id
                (merge product-data {current-location: updated-location})
            )
            (map-set product-event-history
                {product-id: product-id, event-id: (create-next-event-id)}
                {
                    from-participant: responsible-participant,
                    to-participant: responsible-participant,
                    event-category: "location-update",
                    timestamp-occurred: block-height,
                    event-details: location-notes
                }
            )
            (ok true)
        )
    )
)
