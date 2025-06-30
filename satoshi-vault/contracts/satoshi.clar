;; Satoshi Vault - STX Lending with Bitcoin Collateral
;; Leverages Stacks' Bitcoin connection for secure lending

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u102))
(define-constant ERR_LOAN_NOT_FOUND (err u103))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u104))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u105))
(define-constant ERR_LOAN_EXPIRED (err u106))
(define-constant ERR_INVALID_LTV (err u107))
(define-constant ERR_REPAYMENT_FAILED (err u108))

;; Configuration constants
(define-constant MAX_LTV u75) ;; 75% loan-to-value ratio
(define-constant LIQUIDATION_THRESHOLD u80) ;; 80% liquidation threshold
(define-constant INTEREST_RATE u5) ;; 5% annual interest rate
(define-constant BLOCKS_PER_YEAR u52560) ;; Approximate blocks per year
(define-constant MIN_LOAN_AMOUNT u1000000) ;; 1 STX minimum loan

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var total-stx-supplied uint u0)
(define-data-var total-stx-borrowed uint u0)
(define-data-var btc-price-oracle uint u50000000000) ;; BTC price in micro-STX (starts at 50,000 STX)
(define-data-var last-price-update uint u0)

;; Data Maps
(define-map loans
  uint
  {
    borrower: principal,
    btc-collateral: uint,
    stx-borrowed: uint,
    interest-accrued: uint,
    created-at: uint,
    last-interest-update: uint,
    is-active: bool
  }
)

(define-map user-loans principal (list 50 uint))
(define-map liquidity-providers principal uint)

;; Private Functions

;; Calculate current interest for a loan
(define-private (calculate-interest (loan-amount uint) (blocks-elapsed uint))
  (let ((annual-interest (/ (* loan-amount INTEREST_RATE) u100)))
    (/ (* annual-interest blocks-elapsed) BLOCKS_PER_YEAR)
  )
)

;; Get current BTC price in micro-STX
(define-private (get-btc-price)
  (var-get btc-price-oracle)
)

;; Calculate collateral value in STX
(define-private (get-collateral-value (btc-amount uint))
  (/ (* btc-amount (get-btc-price)) u100000000) ;; Convert from satoshis to STX
)

;; Check if loan is healthy (below liquidation threshold)
(define-private (is-loan-healthy (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
      (let (
        (collateral-value (get-collateral-value (get btc-collateral loan-data)))
        (total-debt (+ (get stx-borrowed loan-data) (get interest-accrued loan-data)))
        (ltv-ratio (/ (* total-debt u100) collateral-value))
      )
      (< ltv-ratio LIQUIDATION_THRESHOLD))
    false
  )
)

;; Update interest for a specific loan
(define-private (update-loan-interest (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
      (let (
        (blocks-elapsed (- block-height (get last-interest-update loan-data)))
        (new-interest (calculate-interest (get stx-borrowed loan-data) blocks-elapsed))
        (updated-loan (merge loan-data {
          interest-accrued: (+ (get interest-accrued loan-data) new-interest),
          last-interest-update: block-height
        }))
      )
      (begin
        (map-set loans loan-id updated-loan)
        true))
    false
  )
)

;; Public Functions

;; Supply STX to the vault for lending
(define-public (supply-stx (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-stx-supplied (+ (var-get total-stx-supplied) amount))
    (map-set liquidity-providers tx-sender 
      (+ (default-to u0 (map-get? liquidity-providers tx-sender)) amount))
    (ok true)
  )
)

;; Withdraw supplied STX from the vault
(define-public (withdraw-stx (amount uint))
  (let ((user-supply (default-to u0 (map-get? liquidity-providers tx-sender))))
    (asserts! (>= user-supply amount) ERR_INSUFFICIENT_LIQUIDITY)
    (try! (as-contract (stx-transfer? amount tx-sender (as-contract tx-sender))))
    (var-set total-stx-supplied (- (var-get total-stx-supplied) amount))
    (map-set liquidity-providers tx-sender (- user-supply amount))
    (ok true)
  )
)

;; Create a loan using Bitcoin as collateral
(define-public (create-loan (btc-collateral uint) (stx-amount uint))
  (let (
    (loan-id (var-get next-loan-id))
    (collateral-value (get-collateral-value btc-collateral))
    (ltv-ratio (/ (* stx-amount u100) collateral-value))
    (available-liquidity (- (var-get total-stx-supplied) (var-get total-stx-borrowed)))
    (user-loan-list (default-to (list) (map-get? user-loans tx-sender)))
  )
    ;; Validations
    (asserts! (>= stx-amount MIN_LOAN_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (<= ltv-ratio MAX_LTV) ERR_INVALID_LTV)
    (asserts! (>= available-liquidity stx-amount) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (> btc-collateral u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to borrower
    (try! (as-contract (stx-transfer? stx-amount tx-sender (as-contract tx-sender))))
    
    ;; Create loan record
    (map-set loans loan-id {
      borrower: tx-sender,
      btc-collateral: btc-collateral,
      stx-borrowed: stx-amount,
      interest-accrued: u0,
      created-at: block-height,
      last-interest-update: block-height,
      is-active: true
    })
    
    ;; Update user loans list
    (map-set user-loans tx-sender (unwrap! (as-max-len? (append user-loan-list loan-id) u50) ERR_LOAN_ALREADY_EXISTS))
    
    ;; Update global state
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-stx-borrowed (+ (var-get total-stx-borrowed) stx-amount))
    
    (ok loan-id)
  )
)

;; Repay loan partially or fully
(define-public (repay-loan (loan-id uint) (repay-amount uint))
  (match (map-get? loans loan-id)
    loan-data
      (begin
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (get is-active loan-data) ERR_LOAN_NOT_FOUND)
        
        ;; Update interest before repayment
        (update-loan-interest loan-id)
        
        (let (
          (updated-loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
          (total-debt (+ (get stx-borrowed updated-loan) (get interest-accrued updated-loan)))
          (actual-repay (if (>= repay-amount total-debt) total-debt repay-amount))
        )
          ;; Transfer repayment
          (try! (stx-transfer? actual-repay tx-sender (as-contract tx-sender)))
          
          ;; Update loan
          (if (>= actual-repay total-debt)
            ;; Full repayment - close loan
            (begin
              (map-set loans loan-id (merge updated-loan { is-active: false }))
              (var-set total-stx-borrowed (- (var-get total-stx-borrowed) (get stx-borrowed updated-loan)))
            )
            ;; Partial repayment
            (let (
              (remaining-principal (if (> actual-repay (get interest-accrued updated-loan))
                                    (- (get stx-borrowed updated-loan) (- actual-repay (get interest-accrued updated-loan)))
                                    (get stx-borrowed updated-loan)))
              (remaining-interest (if (> actual-repay (get interest-accrued updated-loan))
                                   u0
                                   (- (get interest-accrued updated-loan) actual-repay)))
            )
              (map-set loans loan-id (merge updated-loan {
                stx-borrowed: remaining-principal,
                interest-accrued: remaining-interest
              }))
              (var-set total-stx-borrowed (- (var-get total-stx-borrowed) 
                (- (get stx-borrowed updated-loan) remaining-principal)))
            )
          )
          (ok actual-repay)
        )
      )
    ERR_LOAN_NOT_FOUND
  )
)

;; Liquidate unhealthy loan
(define-public (liquidate-loan (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
      (begin
        (asserts! (get is-active loan-data) ERR_LOAN_NOT_FOUND)
        (update-loan-interest loan-id)
        
        (let ((updated-loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
          (asserts! (not (is-loan-healthy loan-id)) ERR_UNAUTHORIZED)
          
          ;; Close the loan and transfer collateral to liquidator
          (map-set loans loan-id (merge updated-loan { is-active: false }))
          (var-set total-stx-borrowed (- (var-get total-stx-borrowed) (get stx-borrowed updated-loan)))
          
          ;; In a real implementation, BTC collateral would be transferred here
          ;; This requires integration with Bitcoin via Stacks' clarity-bitcoin library
          
          (ok true)
        )
      )
    ERR_LOAN_NOT_FOUND
  )
)

;; Update BTC price oracle (restricted to contract owner)
(define-public (update-btc-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set btc-price-oracle new-price)
    (var-set last-price-update block-height)
    (ok true)
  )
)

;; Read-only functions

;; Get loan details
(define-read-only (get-loan (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
      (let (
        (blocks-elapsed (- block-height (get last-interest-update loan-data)))
        (current-interest (+ (get interest-accrued loan-data) 
                           (calculate-interest (get stx-borrowed loan-data) blocks-elapsed)))
        (total-debt (+ (get stx-borrowed loan-data) current-interest))
        (collateral-value (get-collateral-value (get btc-collateral loan-data)))
        (current-ltv (if (> collateral-value u0) (/ (* total-debt u100) collateral-value) u0))
      )
      (ok {
        loan-data: loan-data,
        current-interest: current-interest,
        total-debt: total-debt,
        collateral-value: collateral-value,
        current-ltv: current-ltv,
        is-healthy: (< current-ltv LIQUIDATION_THRESHOLD)
      }))
    ERR_LOAN_NOT_FOUND
  )
)

;; Get user's loans
(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-loans user))
)

;; Get vault statistics
(define-read-only (get-vault-stats)
  {
    total-stx-supplied: (var-get total-stx-supplied),
    total-stx-borrowed: (var-get total-stx-borrowed),
    available-liquidity: (- (var-get total-stx-supplied) (var-get total-stx-borrowed)),
    btc-price: (var-get btc-price-oracle),
    utilization-rate: (if (> (var-get total-stx-supplied) u0)
                        (/ (* (var-get total-stx-borrowed) u100) (var-get total-stx-supplied))
                        u0)
  }
)

;; Get user's supplied liquidity
(define-read-only (get-user-liquidity (user principal))
  (default-to u0 (map-get? liquidity-providers user))
)