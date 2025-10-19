;; Fractional Real Estate Ownership Platform
;; Smart contract for tokenized real estate with governance and income distribution

;; Error constants
(define-constant ERR-FORBIDDEN (err u100))
(define-constant ERR-MISSING (err u101))
(define-constant ERR-BAD-PARAMS (err u102))
(define-constant ERR-INACTIVE (err u103))
(define-constant ERR-LOW-BALANCE (err u104))
(define-constant ERR-NO-REVENUE (err u105))
(define-constant ERR-VOTE-CLOSED (err u106))
(define-constant ERR-VOTE-ACTIVE (err u107))
(define-constant ERR-FAILED (err u108))
(define-constant ERR-EXECUTED (err u109))

;; Contract owner
(define-constant SYSTEM-ADMIN tx-sender)

;; Property registry
(define-map property-map
  { property-id: uint }
  {
    name: (string-utf8 128),
    location: (string-utf8 128),
    total-supply: uint,
    price-per-token: uint,
    is-active: bool,
    property-admin: principal,
    creation-block: uint
  }
)

;; Token balances for each property
(define-map balance-map
  { property-id: uint, holder: principal }
  { balance: uint }
)

;; Issued token tracking
(define-map supply-map
  { property-id: uint }
  { issued-amount: uint }
)

;; Income distribution data
(define-map revenue-map
  { property-id: uint }
  {
    total-revenue: uint,
    revenue-per-token: uint,
    last-update: uint
  }
)

;; Income claim tracking
(define-map claim-map
  { property-id: uint, claimant: principal }
  {
    claimed-per-token: uint,
    last-claim-block: uint
  }
)

;; Governance proposal data
(define-map proposal-map
  { property-id: uint, proposal-id: uint }
  {
    title: (string-utf8 128),
    description: (string-utf8 256),
    creator: principal,
    start-block: uint,
    end-block: uint,
    yes-votes: uint,
    no-votes: uint,
    is-executed: bool,
    category: (string-ascii 32)
  }
)

;; Voting records
(define-map vote-map
  { property-id: uint, proposal-id: uint, voter: principal }
  { support: bool, weight: uint }
)

;; ID counters
(define-data-var property-id-counter uint u1)
(define-map proposal-id-counter { property-id: uint } { next-id: uint })

;; Helper: Check if caller is contract admin
(define-private (check-admin)
  (is-eq tx-sender SYSTEM-ADMIN)
)

;; Helper: Check if caller is property admin
(define-private (check-owner (property-id uint))
  (match (map-get? property-map { property-id: property-id })
    prop (is-eq tx-sender (get property-admin prop))
    false
  )
)

;; Helper: Get property safely
(define-private (get-property (property-id uint))
  (ok (unwrap! (map-get? property-map { property-id: property-id }) ERR-MISSING))
)

;; Helper: Get token balance
(define-private (fetch-balance (property-id uint) (account principal))
  (default-to u0 
    (get balance (map-get? balance-map { property-id: property-id, holder: account }))
  )
)

;; Create a new tokenized property
(define-public (create-property 
                (name (string-utf8 128))
                (location (string-utf8 128))
                (total-supply uint)
                (price-per-token uint))
  (let ((new-id (var-get property-id-counter)))
    ;; Input validation
    (asserts! (check-admin) ERR-FORBIDDEN)
    (asserts! (> total-supply u0) ERR-BAD-PARAMS)
    (asserts! (> price-per-token u0) ERR-BAD-PARAMS)
    (asserts! (> (len name) u0) ERR-BAD-PARAMS)
    (asserts! (> (len location) u0) ERR-BAD-PARAMS)
    
    ;; Register property
    (map-set property-map
      { property-id: new-id }
      {
        name: name,
        location: location,
        total-supply: total-supply,
        price-per-token: price-per-token,
        is-active: true,
        property-admin: tx-sender,
        creation-block: block-height
      }
    )
    
    ;; Initialize related data
    (map-set supply-map { property-id: new-id } { issued-amount: u0 })
    (map-set revenue-map 
      { property-id: new-id } 
      { total-revenue: u0, revenue-per-token: u0, last-update: u0 }
    )
    (map-set proposal-id-counter { property-id: new-id } { next-id: u0 })
    
    ;; Update counter
    (var-set property-id-counter (+ new-id u1))
    (ok new-id)
  )
)

;; Purchase property tokens
(define-public (buy-tokens (property-id uint) (amount uint))
  (let (
    (property-data (try! (get-property property-id)))
    (purchase-cost (* amount (get price-per-token property-data)))
    (current-supply (get issued-amount (unwrap! (map-get? supply-map { property-id: property-id }) ERR-MISSING)))
    (buyer-balance (fetch-balance property-id tx-sender))
  )
    ;; Validation checks
    (asserts! (get is-active property-data) ERR-INACTIVE)
    (asserts! (> amount u0) ERR-BAD-PARAMS)
    (asserts! (<= (+ current-supply amount) (get total-supply property-data)) ERR-LOW-BALANCE)
    
    ;; Process payment
    (try! (stx-transfer? purchase-cost tx-sender (as-contract tx-sender)))
    
    ;; Update token balance
    (map-set balance-map
      { property-id: property-id, holder: tx-sender }
      { balance: (+ buyer-balance amount) }
    )
    
    ;; Update supply counter
    (map-set supply-map
      { property-id: property-id }
      { issued-amount: (+ current-supply amount) }
    )
    
    ;; Initialize claim tracking for new holders
    (if (is-eq buyer-balance u0)
      (map-set claim-map
        { property-id: property-id, claimant: tx-sender }
        {
          claimed-per-token: (get revenue-per-token (unwrap-panic (map-get? revenue-map { property-id: property-id }))),
          last-claim-block: block-height
        }
      )
      true
    )
    
    (ok amount)
  )
)

;; Add revenue to property pool
(define-public (add-revenue (property-id uint) (amount uint))
  (let (
    (property-data (try! (get-property property-id)))
    (pool-data (unwrap! (map-get? revenue-map { property-id: property-id }) ERR-MISSING))
    (current-supply (get issued-amount (unwrap! (map-get? supply-map { property-id: property-id }) ERR-MISSING)))
    (revenue-increment (if (> current-supply u0) (/ amount current-supply) u0))
  )
    ;; Authorization and validation
    (asserts! (get is-active property-data) ERR-INACTIVE)
    (asserts! (check-owner property-id) ERR-FORBIDDEN)
    (asserts! (> amount u0) ERR-BAD-PARAMS)
    
    ;; Transfer revenue to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update revenue pool
    (map-set revenue-map
      { property-id: property-id }
      {
        total-revenue: (+ (get total-revenue pool-data) amount),
        revenue-per-token: (+ (get revenue-per-token pool-data) revenue-increment),
        last-update: block-height
      }
    )
    
    (ok amount)
  )
)

;; Claim accumulated revenue
(define-public (claim-revenue (property-id uint))
  (let (
    (property-data (try! (get-property property-id)))
    (pool-data (unwrap! (map-get? revenue-map { property-id: property-id }) ERR-MISSING))
    (holder-balance (fetch-balance property-id tx-sender))
    (claim-data (default-to 
      { claimed-per-token: u0, last-claim-block: u0 }
      (map-get? claim-map { property-id: property-id, claimant: tx-sender })
    ))
    (unclaimed-per-token (- (get revenue-per-token pool-data) (get claimed-per-token claim-data)))
    (withdrawal-amount (* holder-balance unclaimed-per-token))
  )
    ;; Validation
    (asserts! (get is-active property-data) ERR-INACTIVE)
    (asserts! (> holder-balance u0) ERR-LOW-BALANCE)
    (asserts! (> withdrawal-amount u0) ERR-NO-REVENUE)
    
    ;; Update claim record
    (map-set claim-map
      { property-id: property-id, claimant: tx-sender }
      {
        claimed-per-token: (get revenue-per-token pool-data),
        last-claim-block: block-height
      }
    )
    
    ;; Transfer revenue to claimer
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
    (ok withdrawal-amount)
  )
)

;; Submit governance proposal
(define-public (create-proposal
                (property-id uint)
                (title (string-utf8 128))
                (description (string-utf8 256))
                (voting-duration uint)
                (category (string-ascii 32)))
  (let (
    (property-data (try! (get-property property-id)))
    (holder-balance (fetch-balance property-id tx-sender))
    (minimum-tokens (/ (get total-supply property-data) u20)) ;; 5% requirement
    (counter-data (unwrap! (map-get? proposal-id-counter { property-id: property-id }) ERR-MISSING))
    (new-proposal-id (get next-id counter-data))
  )
    ;; Validation
    (asserts! (get is-active property-data) ERR-INACTIVE)
    (asserts! (>= holder-balance minimum-tokens) ERR-LOW-BALANCE)
    (asserts! (> voting-duration u0) ERR-BAD-PARAMS)
    (asserts! (> (len title) u0) ERR-BAD-PARAMS)
    
    ;; Create proposal
    (map-set proposal-map
      { property-id: property-id, proposal-id: new-proposal-id }
      {
        title: title,
        description: description,
        creator: tx-sender,
        start-block: block-height,
        end-block: (+ block-height voting-duration),
        yes-votes: u0,
        no-votes: u0,
        is-executed: false,
        category: category
      }
    )
    
    ;; Update counter
    (map-set proposal-id-counter { property-id: property-id } { next-id: (+ new-proposal-id u1) })
    (ok new-proposal-id)
  )
)

;; Cast vote on proposal
(define-public (vote (property-id uint) (proposal-id uint) (support bool))
  (let (
    (property-data (try! (get-property property-id)))
    (proposal-data (unwrap! (map-get? proposal-map { property-id: property-id, proposal-id: proposal-id }) ERR-MISSING))
    (voter-balance (fetch-balance property-id tx-sender))
    (previous-vote (map-get? vote-map { property-id: property-id, proposal-id: proposal-id, voter: tx-sender }))
  )
    ;; Validation
    (asserts! (get is-active property-data) ERR-INACTIVE)
    (asserts! (> voter-balance u0) ERR-LOW-BALANCE)
    (asserts! (< block-height (get end-block proposal-data)) ERR-VOTE-CLOSED)
    (asserts! (not (get is-executed proposal-data)) ERR-EXECUTED)
    
    ;; Remove previous vote if exists
    (match previous-vote
      old-vote 
        (map-set proposal-map
          { property-id: property-id, proposal-id: proposal-id }
          (if (get support old-vote)
            (merge proposal-data { yes-votes: (- (get yes-votes proposal-data) (get weight old-vote)) })
            (merge proposal-data { no-votes: (- (get no-votes proposal-data) (get weight old-vote)) })
          )
        )
      true
    )
    
    ;; Record new vote
    (map-set vote-map
      { property-id: property-id, proposal-id: proposal-id, voter: tx-sender }
      { support: support, weight: voter-balance }
    )
    
    ;; Update proposal tallies
    (map-set proposal-map
      { property-id: property-id, proposal-id: proposal-id }
      (if support
        (merge proposal-data { yes-votes: (+ (get yes-votes proposal-data) voter-balance) })
        (merge proposal-data { no-votes: (+ (get no-votes proposal-data) voter-balance) })
      )
    )
    
    (ok true)
  )
)

;; Execute approved proposal
(define-public (finalize-proposal (property-id uint) (proposal-id uint))
  (let (
    (property-data (try! (get-property property-id)))
    (proposal-data (unwrap! (map-get? proposal-map { property-id: property-id, proposal-id: proposal-id }) ERR-MISSING))
    (total-votes (+ (get yes-votes proposal-data) (get no-votes proposal-data)))
    (quorum-threshold (/ (get total-supply property-data) u10)) ;; 10% quorum
  )
    ;; Validation
    (asserts! (get is-active property-data) ERR-INACTIVE)
    (asserts! (>= block-height (get end-block proposal-data)) ERR-VOTE-ACTIVE)
    (asserts! (not (get is-executed proposal-data)) ERR-EXECUTED)
    (asserts! (>= total-votes quorum-threshold) ERR-FAILED)
    (asserts! (> (get yes-votes proposal-data) (get no-votes proposal-data)) ERR-FAILED)
    
    ;; Mark as executed
    (map-set proposal-map
      { property-id: property-id, proposal-id: proposal-id }
      (merge proposal-data { is-executed: true })
    )
    
    (ok true)
  )
)

;; Read-only: Get property information
(define-read-only (fetch-property (property-id uint))
  (map-get? property-map { property-id: property-id })
)

;; Read-only: Get token balance
(define-read-only (fetch-balance-info (property-id uint) (account principal))
  (fetch-balance property-id account)
)

;; Read-only: Get proposal details
(define-read-only (fetch-proposal (property-id uint) (proposal-id uint))
  (map-get? proposal-map { property-id: property-id, proposal-id: proposal-id })
)

;; Read-only: Calculate claimable revenue
(define-read-only (get-claimable (property-id uint) (account principal))
  (match (map-get? revenue-map { property-id: property-id })
    pool-data
      (let (
        (account-balance (fetch-balance property-id account))
        (claim-data (default-to 
          { claimed-per-token: u0, last-claim-block: u0 }
          (map-get? claim-map { property-id: property-id, claimant: account })
        ))
        (unclaimed-per-token (- (get revenue-per-token pool-data) (get claimed-per-token claim-data)))
      )
        (* account-balance unclaimed-per-token)
      )
    u0
  )
)

;; Read-only: Get total properties count
(define-read-only (fetch-count)
  (- (var-get property-id-counter) u1)
)