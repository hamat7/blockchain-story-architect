;; Collaborative Story Writing Platform

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAXIMUM_CHAPTERS_PER_STORY u50)
(define-constant MINIMUM_VOTING_PERIOD_BLOCKS u144)  ;; ~24 hours in blocks
(define-constant MAXIMUM_VOTING_PERIOD_BLOCKS u1440) ;; ~10 days in blocks
(define-constant MAXIMUM_VOTERS_PER_DECISION u1000)

;; Error Constants
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_STORY_NOT_FOUND (err u101))
(define-constant ERR_STORY_ALREADY_EXISTS (err u102))
(define-constant ERR_VOTING_PERIOD_ENDED (err u103))
(define-constant ERR_INVALID_VOTE_OPTION (err u104))
(define-constant ERR_NOT_STORY_CONTRIBUTOR (err u105))
(define-constant ERR_CHAPTER_LIMIT_EXCEEDED (err u106))
(define-constant ERR_DUPLICATE_VOTER (err u107))
(define-constant ERR_STORY_CURRENTLY_PAUSED (err u108))
(define-constant ERR_INVALID_VOTING_DURATION (err u109))
(define-constant ERR_STORY_ALREADY_COMPLETED (err u110))
(define-constant ERR_INVALID_INPUT (err u111))
(define-constant ERR_NFT_MINT_FAILED (err u112))
(define-constant ERR_INVALID_DECISION (err u113))
(define-constant ERR_INVALID_ADDRESS (err u114))

;; Data Maps
(define-map story_details
  { story-identifier: uint }
  {
    story-title: (string-ascii 100),
    chapter-count: uint,
    completion-status: bool,
    pause-status: bool,
    creation-timestamp: uint,
    story-category: (string-ascii 20),
    story-owner: principal
  }
)

(define-map chapter_contents
  { story-identifier: uint, chapter-number: uint }
  {
    chapter-text: (string-utf8 1000),
    chapter-author: principal,
    chapter-title: (string-ascii 100),
    creation-timestamp: uint
  }
)

(define-map story_plot_decisions
  { story-identifier: uint, decision-number: uint }
  {
    decision-options: (list 2 (string-ascii 100)),
    option-vote-counts: (list 2 uint),
    voting-active: bool,
    creation-timestamp: uint,
    voting-deadline: uint,
    total-voter-count: uint
  }
)

(define-map story_contributor_registry 
  { story-identifier: uint, contributor-address: principal } 
  { contributor-role: (string-ascii 10), join-timestamp: uint }
)

(define-map decision_voter_registry
  { story-identifier: uint, decision-number: uint, voter-address: principal }
  { vote-timestamp: uint, chosen-option: uint }
)

;; NFT Definitions
(define-non-fungible-token story_ownership_token uint)

;; Variables
(define-data-var story_counter uint u0)
(define-data-var plot_decision_counter uint u0)

;; Events
(define-private (emit-story-event (event-name (string-ascii 20)) (story-identifier uint))
  (print { event-name: event-name, story-identifier: story-identifier, block-timestamp: block-height })
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-story-owner (story-identifier uint))
  (let ((story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) false)))
    (is-eq tx-sender (get story-owner story-data))
  )
)

(define-private (has-contributor-rights (story-identifier uint))
  (match (map-get? story_contributor_registry 
         { story-identifier: story-identifier, contributor-address: tx-sender })
    contributor-data true
    false
  )
)

(define-private (is-valid-string (input (string-ascii 100)))
  (< u0 (len input))
)

(define-private (is-valid-story-id (story-identifier uint))
  (is-some (map-get? story_details { story-identifier: story-identifier }))
)

(define-private (is-valid-decision (story-identifier uint) (decision-number uint))
  (is-some (map-get? story_plot_decisions { story-identifier: story-identifier, decision-number: decision-number }))
)

(define-private (is-valid-principal (address principal))
  (and 
    (not (is-eq address CONTRACT_OWNER))  ;; Prevent registering contract owner as contributor
    (not (is-eq address (as-contract tx-sender)))  ;; Prevent registering contract itself
    true
  )
)

;; Public Functions
(define-public (create-new-story (story-title (string-ascii 100)) (story-category (string-ascii 20)))
  (let
    (
      (new-story-identifier (+ (var-get story_counter) u1))
    )
    (asserts! (is-valid-string story-title) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-string story-category) (err ERR_INVALID_INPUT))
    (match (nft-mint? story_ownership_token new-story-identifier tx-sender)
      success (begin
        (map-set story_details 
          { story-identifier: new-story-identifier }
          {
            story-title: story-title,
            chapter-count: u0,
            completion-status: false,
            pause-status: false,
            creation-timestamp: block-height,
            story-category: story-category,
            story-owner: tx-sender
          }
        )
        (map-set story_contributor_registry
          { story-identifier: new-story-identifier, contributor-address: tx-sender }
          { contributor-role: "owner", join-timestamp: block-height }
        )
        (var-set story_counter new-story-identifier)
        (emit-story-event "story-created" new-story-identifier)
        (ok new-story-identifier))
      error (err ERR_NFT_MINT_FAILED))
  )
)

(define-public (add-story-chapter 
    (story-identifier uint) 
    (chapter-text (string-utf8 1000))
    (chapter-title (string-ascii 100))
  )
  (let
    (
      (story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) (err ERR_STORY_NOT_FOUND)))
      (next-chapter-number (+ (get chapter-count story-data) u1))
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (is-valid-string chapter-title) (err ERR_INVALID_INPUT))
    (asserts! (> (len chapter-text) u0) (err ERR_INVALID_INPUT))
    (asserts! (has-contributor-rights story-identifier) (err ERR_NOT_STORY_CONTRIBUTOR))
    (asserts! (not (get completion-status story-data)) (err ERR_STORY_ALREADY_COMPLETED))
    (asserts! (not (get pause-status story-data)) (err ERR_STORY_CURRENTLY_PAUSED))
    (asserts! (<= next-chapter-number MAXIMUM_CHAPTERS_PER_STORY) (err ERR_CHAPTER_LIMIT_EXCEEDED))
    
    (map-set chapter_contents 
      { story-identifier: story-identifier, chapter-number: next-chapter-number }
      {
        chapter-text: chapter-text,
        chapter-author: tx-sender,
        chapter-title: chapter-title,
        creation-timestamp: block-height
      }
    )
    (map-set story_details { story-identifier: story-identifier }
      (merge story-data { chapter-count: next-chapter-number }))
    
    (emit-story-event "chapter-added" story-identifier)
    (ok next-chapter-number)
  )
)

(define-public (create-plot-decision 
    (story-identifier uint) 
    (first-option (string-ascii 100)) 
    (second-option (string-ascii 100))
    (voting-duration uint)
  )
  (let
    (
      (story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) (err ERR_STORY_NOT_FOUND)))
      (new-decision-number (+ (var-get plot_decision_counter) u1))
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (is-valid-string first-option) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-string second-option) (err ERR_INVALID_INPUT))
    (asserts! (has-contributor-rights story-identifier) (err ERR_NOT_STORY_CONTRIBUTOR))
    (asserts! (not (get completion-status story-data)) (err ERR_STORY_ALREADY_COMPLETED))
    (asserts! (not (get pause-status story-data)) (err ERR_STORY_CURRENTLY_PAUSED))
    (asserts! (and (>= voting-duration MINIMUM_VOTING_PERIOD_BLOCKS) (<= voting-duration MAXIMUM_VOTING_PERIOD_BLOCKS)) (err ERR_INVALID_VOTING_DURATION))
    
    (map-set story_plot_decisions 
      { story-identifier: story-identifier, decision-number: new-decision-number }
      {
        decision-options: (list first-option second-option),
        option-vote-counts: (list u0 u0),
        voting-active: true,
        creation-timestamp: block-height,
        voting-deadline: (+ block-height voting-duration),
        total-voter-count: u0
      }
    )
    (var-set plot_decision_counter new-decision-number)
    (emit-story-event "decision-created" story-identifier)
    (ok new-decision-number)
  )
)

(define-public (submit-plot-vote (story-identifier uint) (decision-number uint) (selected-option uint))
  (let
    (
      (decision-data (unwrap! (map-get? story_plot_decisions 
        { story-identifier: story-identifier, decision-number: decision-number }) 
        (err ERR_STORY_NOT_FOUND)))
      (current-vote-counts (get option-vote-counts decision-data))
      (voter-record-key { story-identifier: story-identifier, 
                         decision-number: decision-number, 
                         voter-address: tx-sender })
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (is-valid-decision story-identifier decision-number) (err ERR_INVALID_DECISION))
    (asserts! (get voting-active decision-data) (err ERR_VOTING_PERIOD_ENDED))
    (asserts! (<= block-height (get voting-deadline decision-data)) (err ERR_VOTING_PERIOD_ENDED))
    (asserts! (or (is-eq selected-option u0) (is-eq selected-option u1)) (err ERR_INVALID_VOTE_OPTION))
    (asserts! (is-none (map-get? decision_voter_registry voter-record-key)) (err ERR_DUPLICATE_VOTER))
    
    (map-set decision_voter_registry 
      voter-record-key 
      { vote-timestamp: block-height, chosen-option: selected-option })
    
    (map-set story_plot_decisions 
      { story-identifier: story-identifier, decision-number: decision-number }
      (merge decision-data {
        option-vote-counts: (list
          (if (is-eq selected-option u0) 
              (+ (default-to u0 (element-at? current-vote-counts u0)) u1) 
              (default-to u0 (element-at? current-vote-counts u0)))
          (if (is-eq selected-option u1) 
              (+ (default-to u0 (element-at? current-vote-counts u1)) u1) 
              (default-to u0 (element-at? current-vote-counts u1)))
        ),
        total-voter-count: (+ (get total-voter-count decision-data) u1)
      })
    )
    
    (emit-story-event "vote-recorded" story-identifier)
    (ok true)
  )
)

(define-public (pause-story-writing (story-identifier uint))
  (let
    (
      (story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) (err ERR_STORY_NOT_FOUND)))
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (or (is-contract-owner) (is-story-owner story-identifier)) (err ERR_UNAUTHORIZED_ACCESS))
    (ok (map-set story_details { story-identifier: story-identifier }
      (merge story-data { pause-status: true })))
  )
)

(define-public (resume-story-writing (story-identifier uint))
  (let
    (
      (story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) (err ERR_STORY_NOT_FOUND)))
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (or (is-contract-owner) (is-story-owner story-identifier)) (err ERR_UNAUTHORIZED_ACCESS))
    (ok (map-set story_details { story-identifier: story-identifier }
      (merge story-data { pause-status: false })))
  )
)

(define-public (register-contributor (story-identifier uint) (contributor-address principal) (contributor-role (string-ascii 10)))
  (let
    (
      (story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) (err ERR_STORY_NOT_FOUND)))
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (is-valid-string contributor-role) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-principal contributor-address) (err ERR_INVALID_ADDRESS))
    (asserts! (or (is-contract-owner) (is-story-owner story-identifier)) (err ERR_UNAUTHORIZED_ACCESS))
    (ok (map-set story_contributor_registry
      { story-identifier: story-identifier, contributor-address: contributor-address }
      { contributor-role: contributor-role, join-timestamp: block-height }))
  )
)

(define-public (mark-story-complete (story-identifier uint))
  (let
    (
      (story-data (unwrap! (map-get? story_details { story-identifier: story-identifier }) (err ERR_STORY_NOT_FOUND)))
    )
    (asserts! (is-valid-story-id story-identifier) (err ERR_STORY_NOT_FOUND))
    (asserts! (or (is-contract-owner) (is-story-owner story-identifier)) (err ERR_UNAUTHORIZED_ACCESS))
    (emit-story-event "story-completed" story-identifier)
    (ok (map-set story_details { story-identifier: story-identifier }
      (merge story-data { completion-status: true })))
  )
)

;; Read-only Functions
(define-read-only (get-story-details (story-identifier uint))
  (map-get? story_details { story-identifier: story-identifier })
)

(define-read-only (get-chapter-details (story-identifier uint) (chapter-number uint))
  (map-get? chapter_contents { story-identifier: story-identifier, chapter-number: chapter-number })
)

(define-read-only (get-decision-details (story-identifier uint) (decision-number uint))
  (map-get? story_plot_decisions { story-identifier: story-identifier, decision-number: decision-number })
)

(define-read-only (get-contributor-status (story-identifier uint) (contributor-address principal))
  (get contributor-role (default-to { contributor-role: "none", join-timestamp: u0 }
    (map-get? story_contributor_registry { story-identifier: story-identifier, contributor-address: contributor-address })))
)

(define-read-only (check-voter-participation (story-identifier uint) (decision-number uint) (voter-address principal))
  (is-some (map-get? decision_voter_registry { story-identifier: story-identifier, decision-number: decision-number, voter-address: voter-address }))
)