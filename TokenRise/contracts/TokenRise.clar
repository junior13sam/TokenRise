;; Decentralized Crowdfunding and Token Launchpad
;; A secure smart contract for launching token projects with crowdfunding capabilities
;; Enables project creators to raise funds and distribute tokens to backers with milestone-based releases

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-campaign-ended (err u104))
(define-constant err-campaign-not-ended (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-already-claimed (err u107))
(define-constant err-milestone-not-reached (err u108))
(define-constant err-unauthorized (err u109))
(define-constant err-campaign-failed (err u110))

;; Campaign duration constants
(define-constant min-campaign-duration u1440) ;; 10 days in blocks
(define-constant max-campaign-duration u14400) ;; 100 days in blocks
(define-constant platform-fee-percentage u3) ;; 3% platform fee

;; Data maps and vars
(define-map campaigns
  { campaign-id: uint }
  {
    creator: principal,
    title: (string-ascii 50),
    description: (string-ascii 200),
    funding-goal: uint,
    current-funding: uint,
    token-supply: uint,
    tokens-per-stx: uint,
    start-block: uint,
    end-block: uint,
    milestone-count: uint,
    milestones-completed: uint,
    is-successful: bool,
    tokens-distributed: bool,
    funds-withdrawn: bool
  }
)

(define-map campaign-backers
  { campaign-id: uint, backer: principal }
  {
    amount-contributed: uint,
    tokens-earned: uint,
    tokens-claimed: bool,
    refund-claimed: bool
  }
)

(define-map campaign-milestones
  { campaign-id: uint, milestone-id: uint }
  {
    description: (string-ascii 100),
    funding-threshold: uint,
    is-completed: bool,
    completion-block: uint
  }
)

(define-data-var next-campaign-id uint u1)
(define-data-var platform-treasury uint u0)

;; Private functions
(define-private (is-campaign-active (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) false)))
    (and 
      (>= block-height (get start-block campaign))
      (<= block-height (get end-block campaign))
      (not (get is-successful campaign))
    )
  )
)

(define-private (calculate-tokens (amount uint) (tokens-per-stx uint))
  (* amount tokens-per-stx)
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount platform-fee-percentage) u100)
)

(define-private (is-funding-goal-reached (campaign-id uint))
  (let ((campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) false)))
    (>= (get current-funding campaign) (get funding-goal campaign))
  )
)

;; Public functions

;; Create a new crowdfunding campaign
(define-public (create-campaign 
  (title (string-ascii 50))
  (description (string-ascii 200))
  (funding-goal uint)
  (token-supply uint)
  (tokens-per-stx uint)
  (duration-blocks uint)
  (milestone-descriptions (list 5 (string-ascii 100)))
  (milestone-thresholds (list 5 uint))
)
  (let (
    (campaign-id (var-get next-campaign-id))
    (start-block block-height)
    (end-block (+ block-height duration-blocks))
    (milestone-count (len milestone-descriptions))
  )
    (asserts! (and (>= duration-blocks min-campaign-duration) (<= duration-blocks max-campaign-duration)) err-invalid-amount)
    (asserts! (> funding-goal u0) err-invalid-amount)
    (asserts! (> token-supply u0) err-invalid-amount)
    (asserts! (> tokens-per-stx u0) err-invalid-amount)
    (asserts! (is-eq (len milestone-descriptions) (len milestone-thresholds)) err-invalid-amount)
    
    ;; Create campaign record
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        token-supply: token-supply,
        tokens-per-stx: tokens-per-stx,
        start-block: start-block,
        end-block: end-block,
        milestone-count: milestone-count,
        milestones-completed: u0,
        is-successful: false,
        tokens-distributed: false,
        funds-withdrawn: false
      }
    )
    
    ;; Create milestone records
    (map create-milestone-entry 
      milestone-descriptions 
      milestone-thresholds
      (list campaign-id campaign-id campaign-id campaign-id campaign-id)
      (list u1 u2 u3 u4 u5)
    )
    
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Helper function to create milestone entries
(define-private (create-milestone-entry 
  (description (string-ascii 100))
  (threshold uint)
  (campaign-id uint)
  (milestone-id uint)
)
  (map-set campaign-milestones
    { campaign-id: campaign-id, milestone-id: milestone-id }
    {
      description: description,
      funding-threshold: threshold,
      is-completed: false,
      completion-block: u0
    }
  )
)

;; Back a campaign with STX
(define-public (back-campaign (campaign-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    (existing-backing (default-to 
      { amount-contributed: u0, tokens-earned: u0, tokens-claimed: false, refund-claimed: false }
      (map-get? campaign-backers { campaign-id: campaign-id, backer: tx-sender })
    ))
    (tokens-earned (calculate-tokens amount (get tokens-per-stx campaign)))
    (new-funding (+ (get current-funding campaign) amount))
  )
    (asserts! (is-campaign-active campaign-id) err-campaign-ended)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update backer record
    (map-set campaign-backers
      { campaign-id: campaign-id, backer: tx-sender }
      {
        amount-contributed: (+ (get amount-contributed existing-backing) amount),
        tokens-earned: (+ (get tokens-earned existing-backing) tokens-earned),
        tokens-claimed: false,
        refund-claimed: false
      }
    )
    
    ;; Update campaign funding
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { current-funding: new-funding })
    )
    
    ;; Check if funding goal reached
    (if (>= new-funding (get funding-goal campaign))
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign { 
          current-funding: new-funding,
          is-successful: true 
        })
      )
      true
    )
    
    (ok tokens-earned)
  )
)

;; Claim tokens after successful campaign
(define-public (claim-tokens (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    (backing (unwrap! (map-get? campaign-backers { campaign-id: campaign-id, backer: tx-sender }) err-not-found))
  )
    (asserts! (get is-successful campaign) err-campaign-failed)
    (asserts! (> block-height (get end-block campaign)) err-campaign-not-ended)
    (asserts! (not (get tokens-claimed backing)) err-already-claimed)
    
    ;; Mark tokens as claimed
    (map-set campaign-backers
      { campaign-id: campaign-id, backer: tx-sender }
      (merge backing { tokens-claimed: true })
    )
    
    ;; In a real implementation, this would mint/transfer actual tokens
    ;; For this demo, we return the token amount that would be distributed
    (ok (get tokens-earned backing))
  )
)

;; Claim refund if campaign failed
(define-public (claim-refund (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    (backing (unwrap! (map-get? campaign-backers { campaign-id: campaign-id, backer: tx-sender }) err-not-found))
  )
    (asserts! (> block-height (get end-block campaign)) err-campaign-not-ended)
    (asserts! (not (get is-successful campaign)) err-campaign-failed)
    (asserts! (not (get refund-claimed backing)) err-already-claimed)
    (asserts! (> (get amount-contributed backing) u0) err-invalid-amount)
    
    ;; Mark refund as claimed
    (map-set campaign-backers
      { campaign-id: campaign-id, backer: tx-sender }
      (merge backing { refund-claimed: true })
    )
    
    ;; Transfer refund
    (try! (as-contract (stx-transfer? (get amount-contributed backing) tx-sender tx-sender)))
    
    (ok (get amount-contributed backing))
  )
)

;; Withdraw funds by campaign creator (milestone-based)
(define-public (withdraw-campaign-funds (campaign-id uint) (milestone-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    (milestone (unwrap! (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }) err-not-found))
    (platform-fee (calculate-platform-fee (get funding-threshold milestone)))
    (creator-amount (- (get funding-threshold milestone) platform-fee))
  )
    (asserts! (is-eq tx-sender (get creator campaign)) err-unauthorized)
    (asserts! (get is-successful campaign) err-campaign-failed)
    (asserts! (not (get is-completed milestone)) err-already-claimed)
    (asserts! (>= (get current-funding campaign) (get funding-threshold milestone)) err-milestone-not-reached)
    
    ;; Mark milestone as completed
    (map-set campaign-milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      (merge milestone { 
        is-completed: true,
        completion-block: block-height 
      })
    )
    
    ;; Update campaign milestones completed
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { 
        milestones-completed: (+ (get milestones-completed campaign) u1)
      })
    )
    
    ;; Transfer funds to creator
    (try! (as-contract (stx-transfer? creator-amount tx-sender (get creator campaign))))
    
    ;; Add platform fee to treasury
    (var-set platform-treasury (+ (var-get platform-treasury) platform-fee))
    
    (ok creator-amount)
  )
)

;; Helper function for progressive release calculation
(define-private (calculate-progressive-release (base-amount uint) (approval-percentage uint))
  (if (>= approval-percentage u75)
    base-amount  ;; Full release for 75%+ approval
    (if (>= approval-percentage u50)
      (/ (* base-amount u75) u100)  ;; 75% release for 50-74% approval
      (/ (* base-amount u50) u100)  ;; 50% release for lower approval
    )
  )
)

;; Helper function to get campaign backer count (simplified for demo)
(define-private (get-campaign-backer-count (campaign-id uint))
  u10  ;; Simplified - in real implementation would count actual backers
)


