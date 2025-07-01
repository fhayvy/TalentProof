;; TalentProof - Reputation-Based Freelance Network
;; A decentralized platform for freelancer reputation management with peer jury dispute resolution

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_INSUFFICIENT_STAKE (err u105))
(define-constant ERR_DISPUTE_EXPIRED (err u106))

;; Data Variables
(define-data-var min-jury-stake uint u1000000) ;; 1 STX minimum
(define-data-var dispute-duration uint u1008) ;; ~7 days in blocks
(define-data-var jury-reward-percentage uint u10) ;; 10%

;; Data Maps
(define-map freelancer-profiles
  principal
  {
    reputation-score: uint,
    completed-jobs: uint,
    total-earned: uint,
    disputes-won: uint,
    disputes-lost: uint,
    active: bool
  }
)

(define-map client-profiles
  principal
  {
    jobs-posted: uint,
    total-spent: uint,
    reputation-score: uint,
    active: bool
  }
)

(define-map job-contracts
  uint
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    description: (string-ascii 500),
    status: (string-ascii 20), ;; "pending", "active", "completed", "disputed"
    created-at: uint,
    completed-at: (optional uint),
    disputed-at: (optional uint)
  }
)

(define-map job-reviews
  uint
  {
    client-rating: uint,
    freelancer-rating: uint,
    client-review: (string-ascii 500),
    freelancer-review: (string-ascii 500),
    reviewed-at: uint
  }
)

(define-map disputes
  uint
  {
    job-id: uint,
    initiator: principal,
    reason: (string-ascii 500),
    status: (string-ascii 20), ;; "open", "voting", "resolved"
    created-at: uint,
    resolution-deadline: uint,
    jury-members: (list 5 principal),
    votes-for-client: uint,
    votes-for-freelancer: uint,
    resolved-in-favor-of: (optional principal)
  }
)

(define-map jury-stakes
  { dispute-id: uint, juror: principal }
  { amount: uint, vote: (optional bool) } ;; true = client, false = freelancer
)

;; Data Variables for counters
(define-data-var next-job-id uint u1)
(define-data-var next-dispute-id uint u1)

;; Public Functions

;; Register as freelancer
(define-public (register-freelancer)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? freelancer-profiles caller)) ERR_ALREADY_EXISTS)
    (ok (map-set freelancer-profiles caller {
      reputation-score: u100,
      completed-jobs: u0,
      total-earned: u0,
      disputes-won: u0,
      disputes-lost: u0,
      active: true
    }))
  )
)

;; Register as client
(define-public (register-client)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? client-profiles caller)) ERR_ALREADY_EXISTS)
    (ok (map-set client-profiles caller {
      jobs-posted: u0,
      total-spent: u0,
      reputation-score: u100,
      active: true
    }))
  )
)

;; Create job contract
(define-public (create-job (freelancer principal) (amount uint) (description (string-ascii 500)))
  (let (
    (job-id (var-get next-job-id))
    (caller tx-sender)
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-some (map-get? client-profiles caller)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? freelancer-profiles freelancer)) ERR_NOT_FOUND)
    
    ;; Escrow the payment
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    
    ;; Create job contract
    (map-set job-contracts job-id {
      client: caller,
      freelancer: freelancer,
      amount: amount,
      description: description,
      status: "pending",
      created-at: block-height,
      completed-at: none,
      disputed-at: none
    })
    
    ;; Update client profile
    (match (map-get? client-profiles caller)
      client-data (map-set client-profiles caller (merge client-data {
        jobs-posted: (+ (get jobs-posted client-data) u1)
      }))
      false
    )
    
    ;; Increment job counter
    (var-set next-job-id (+ job-id u1))
    (ok job-id)
  )
)

;; Accept job (freelancer)
(define-public (accept-job (job-id uint))
  (let (
    (caller tx-sender)
    (job-data (unwrap! (map-get? job-contracts job-id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq caller (get freelancer job-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job-data) "pending") ERR_INVALID_STATUS)
    
    (ok (map-set job-contracts job-id (merge job-data {
      status: "active"
    })))
  )
)

;; Complete job and release payment
(define-public (complete-job (job-id uint))
  (let (
    (caller tx-sender)
    (job-data (unwrap! (map-get? job-contracts job-id) ERR_NOT_FOUND))
    (freelancer (get freelancer job-data))
    (amount (get amount job-data))
  )
    (asserts! (is-eq caller (get client job-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job-data) "active") ERR_INVALID_STATUS)
    
    ;; Release payment to freelancer
    (try! (as-contract (stx-transfer? amount tx-sender freelancer)))
    
    ;; Update job status
    (map-set job-contracts job-id (merge job-data {
      status: "completed",
      completed-at: (some block-height)
    }))
    
    ;; Update freelancer profile
    (match (map-get? freelancer-profiles freelancer)
      freelancer-data (map-set freelancer-profiles freelancer (merge freelancer-data {
        completed-jobs: (+ (get completed-jobs freelancer-data) u1),
        total-earned: (+ (get total-earned freelancer-data) amount),
        reputation-score: (+ (get reputation-score freelancer-data) u5)
      }))
      false
    )
    
    ;; Update client profile  
    (match (map-get? client-profiles caller)
      client-data (map-set client-profiles caller (merge client-data {
        total-spent: (+ (get total-spent client-data) amount)
      }))
      false
    )
    
    (ok true)
  )
)

;; Submit review
(define-public (submit-review (job-id uint) (rating uint) (review (string-ascii 500)))
  (let (
    (caller tx-sender)
    (job-data (unwrap! (map-get? job-contracts job-id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get status job-data) "completed") ERR_INVALID_STATUS)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_AMOUNT)
    (asserts! (or (is-eq caller (get client job-data)) 
                  (is-eq caller (get freelancer job-data))) ERR_UNAUTHORIZED)
    
    (let ((existing-review (map-get? job-reviews job-id)))
      (if (is-some existing-review)
        ;; Update existing review
        (let ((review-data (unwrap-panic existing-review)))
          (if (is-eq caller (get client job-data))
            ;; Client review
            (ok (map-set job-reviews job-id (merge review-data {
              client-rating: rating,
              client-review: review
            })))
            ;; Freelancer review
            (ok (map-set job-reviews job-id (merge review-data {
              freelancer-rating: rating,
              freelancer-review: review
            })))
          )
        )
        ;; Create new review
        (if (is-eq caller (get client job-data))
          ;; Client review
          (ok (map-set job-reviews job-id {
            client-rating: rating,
            freelancer-rating: u0,
            client-review: review,
            freelancer-review: "",
            reviewed-at: block-height
          }))
          ;; Freelancer review
          (ok (map-set job-reviews job-id {
            client-rating: u0,
            freelancer-rating: rating,
            client-review: "",
            freelancer-review: review,
            reviewed-at: block-height
          }))
        )
      )
    )
  )
)

;; Initiate dispute
(define-public (initiate-dispute (job-id uint) (reason (string-ascii 500)))
  (let (
    (caller tx-sender)
    (job-data (unwrap! (map-get? job-contracts job-id) ERR_NOT_FOUND))
    (dispute-id (var-get next-dispute-id))
  )
    (asserts! (or (is-eq caller (get client job-data)) 
                  (is-eq caller (get freelancer job-data))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status job-data) "active") ERR_INVALID_STATUS)
    
    ;; Update job status
    (map-set job-contracts job-id (merge job-data {
      status: "disputed",
      disputed-at: (some block-height)
    }))
    
    ;; Create dispute
    (map-set disputes dispute-id {
      job-id: job-id,
      initiator: caller,
      reason: reason,
      status: "open",
      created-at: block-height,
      resolution-deadline: (+ block-height (var-get dispute-duration)),
      jury-members: (list),
      votes-for-client: u0,
      votes-for-freelancer: u0,
      resolved-in-favor-of: none
    })
    
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

;; Join jury for dispute (requires stake)
(define-public (join-jury (dispute-id uint))
  (let (
    (caller tx-sender)
    (dispute-data (unwrap! (map-get? disputes dispute-id) ERR_NOT_FOUND))
    (min-stake (var-get min-jury-stake))
  )
    (asserts! (is-eq (get status dispute-data) "open") ERR_INVALID_STATUS)
    (asserts! (< (len (get jury-members dispute-data)) u5) ERR_INVALID_STATUS)
    
    ;; Stake STX
    (try! (stx-transfer? min-stake caller (as-contract tx-sender)))
    
    ;; Add to jury
    (map-set disputes dispute-id (merge dispute-data {
      jury-members: (unwrap! (as-max-len? (append (get jury-members dispute-data) caller) u5) ERR_INVALID_STATUS),
      status: (if (is-eq (+ (len (get jury-members dispute-data)) u1) u5) "voting" "open")
    }))
    
    ;; Record stake
    (map-set jury-stakes { dispute-id: dispute-id, juror: caller } {
      amount: min-stake,
      vote: none
    })
    
    (ok true)
  )
)

;; Cast vote in dispute
(define-public (vote-on-dispute (dispute-id uint) (vote-for-client bool))
  (let (
    (caller tx-sender)
    (dispute-data (unwrap! (map-get? disputes dispute-id) ERR_NOT_FOUND))
    (stake-data (unwrap! (map-get? jury-stakes { dispute-id: dispute-id, juror: caller }) ERR_UNAUTHORIZED))
  )
    (asserts! (is-eq (get status dispute-data) "voting") ERR_INVALID_STATUS)
    (asserts! (< block-height (get resolution-deadline dispute-data)) ERR_DISPUTE_EXPIRED)
    (asserts! (is-none (get vote stake-data)) ERR_ALREADY_EXISTS)
    
    ;; Record vote
    (map-set jury-stakes { dispute-id: dispute-id, juror: caller } (merge stake-data {
      vote: (some vote-for-client)
    }))
    
    ;; Update vote counts
    (if vote-for-client
      (map-set disputes dispute-id (merge dispute-data {
        votes-for-client: (+ (get votes-for-client dispute-data) u1)
      }))
      (map-set disputes dispute-id (merge dispute-data {
        votes-for-freelancer: (+ (get votes-for-freelancer dispute-data) u1)
      }))
    )
    
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-freelancer-profile (freelancer principal))
  (map-get? freelancer-profiles freelancer)
)

(define-read-only (get-client-profile (client principal))
  (map-get? client-profiles client)
)

(define-read-only (get-job-contract (job-id uint))
  (map-get? job-contracts job-id)
)

(define-read-only (get-job-review (job-id uint))
  (map-get? job-reviews job-id)
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-next-job-id)
  (var-get next-job-id)
)

(define-read-only (get-next-dispute-id)
  (var-get next-dispute-id)
)