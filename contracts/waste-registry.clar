;; WasteRegistry Smart Contract
;; This contract registers waste batches immutably on the Stacks blockchain, ensuring traceability and preventing duplicates.
;; It includes features for ownership, versioning, collaborators, tags, status, and more for robust waste management.

;; Constants
(define-constant ERR-ALREADY-REGISTERED u1)
(define-constant ERR-NOT-OWNER u2)
(define-constant ERR-INVALID-PARAM u3)
(define-constant ERR-NOT-FOUND u4)
(define-constant ERR-PERMISSION-DENIED u5)
(define-constant ERR-EXPIRED u6)
(define-constant MAX-TAGS u10)
(define-constant MAX-PERMISSIONS u5)

;; Data Maps
(define-map waste-registry
  { hash: (buff 32) }  ;; Unique hash of the waste batch (e.g., SHA-256 of details)
  {
    owner: principal,
    timestamp: uint,
    waste-type: (string-utf8 50),  ;; e.g., "e-waste", "plastics"
    origin: (string-utf8 100),     ;; Location or generator details
    description: (string-utf8 500),
    quantity: uint,                ;; In kg or units
    status: (string-utf8 20)       ;; e.g., "registered", "collected"
  }
)

(define-map waste-versions
  { hash: (buff 32), version: uint }
  {
    updated-hash: (buff 32),
    update-notes: (string-utf8 200),
    timestamp: uint,
    updater: principal
  }
)

(define-map waste-tags
  { hash: (buff 32) }
  {
    tags: (list 10 (string-utf8 20))  ;; e.g., "hazardous", "recyclable"
  }
)

(define-map waste-collaborators
  { hash: (buff 32), collaborator: principal }
  {
    role: (string-utf8 50),            ;; e.g., "handler", "inspector"
    permissions: (list 5 (string-utf8 20)),  ;; e.g., "update-status", "view-details"
    added-at: uint
  }
)

(define-map handling-licenses
  { hash: (buff 32), licensee: principal }
  {
    expiry: uint,
    terms: (string-utf8 200),
    active: bool
  }
)

(define-map waste-status-history
  { hash: (buff 32), update-id: uint }
  {
    status: (string-utf8 20),
    timestamp: uint,
    updater: principal
  }
)

(define-map revenue-shares
  { hash: (buff 32), participant: principal }
  {
    percentage: uint,  ;; 0-100
    total-received: uint
  }
)

;; Non-fungible data for last version/update IDs (counters)
(define-data-var last-version-id uint u0)
(define-data-var last-status-update-id uint u0)

;; Public Functions

(define-public (register-waste (hash (buff 32)) (waste-type (string-utf8 50)) (origin (string-utf8 100)) (description (string-utf8 500)) (quantity uint))
  (let
    ((existing (map-get? waste-registry {hash: hash})))
    (if (is-some existing)
      (err ERR-ALREADY-REGISTERED)
      (begin
        (map-set waste-registry
          {hash: hash}
          {
            owner: tx-sender,
            timestamp: block-height,
            waste-type: waste-type,
            origin: origin,
            description: description,
            quantity: quantity,
            status: "registered"
          }
        )
        (ok true)
      )
    )
  )
)

(define-public (transfer-ownership (hash (buff 32)) (new-owner principal))
  (let ((entry (map-get? waste-registry {hash: hash})))
    (if (and (is-some entry) (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender))
      (begin
        (map-set waste-registry {hash: hash} (merge (unwrap! entry (err ERR-NOT-FOUND)) {owner: new-owner}))
        (ok true)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

(define-public (update-waste-version (original-hash (buff 32)) (new-hash (buff 32)) (notes (string-utf8 200)))
  (let ((entry (map-get? waste-registry {hash: original-hash})))
    (if (and (is-some entry) (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender))
      (let ((new-version (+ (var-get last-version-id) u1)))
        (var-set last-version-id new-version)
        (map-set waste-versions
          {hash: original-hash, version: new-version}
          {
            updated-hash: new-hash,
            update-notes: notes,
            timestamp: block-height,
            updater: tx-sender
          }
        )
        (ok new-version)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

(define-public (add-tags (hash (buff 32)) (tags (list 10 (string-utf8 20))))
  (let ((entry (map-get? waste-registry {hash: hash})))
    (if (and (is-some entry) (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender))
      (begin
        (map-set waste-tags {hash: hash} {tags: tags})
        (ok true)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

(define-public (add-collaborator (hash (buff 32)) (collaborator principal) (role (string-utf8 50)) (permissions (list 5 (string-utf8 20))))
  (let ((entry (map-get? waste-registry {hash: hash})))
    (if (and (is-some entry) (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender))
      (begin
        (map-set waste-collaborators
          {hash: hash, collaborator: collaborator}
          {
            role: role,
            permissions: permissions,
            added-at: block-height
          }
        )
        (ok true)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

(define-public (grant-handling-license (hash (buff 32)) (licensee principal) (duration uint) (terms (string-utf8 200)))
  (let ((entry (map-get? waste-registry {hash: hash})))
    (if (and (is-some entry) (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender))
      (begin
        (map-set handling-licenses
          {hash: hash, licensee: licensee}
          {
            expiry: (+ block-height duration),
            terms: terms,
            active: true
          }
        )
        (ok true)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

(define-public (update-status (hash (buff 32)) (new-status (string-utf8 20)))
  (let ((entry (map-get? waste-registry {hash: hash})))
    (if (and (is-some entry) (or (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender)
                                 (has-permission hash tx-sender "update-status")))
      (let ((new-update-id (+ (var-get last-status-update-id) u1)))
        (var-set last-status-update-id new-update-id)
        (map-set waste-status-history
          {hash: hash, update-id: new-update-id}
          {
            status: new-status,
            timestamp: block-height,
            updater: tx-sender
          }
        )
        (map-set waste-registry {hash: hash} (merge (unwrap! entry (err ERR-NOT-FOUND)) {status: new-status}))
        (ok true)
      )
      (err ERR-PERMISSION-DENIED)
    )
  )
)

(define-public (set-revenue-share (hash (buff 32)) (participant principal) (percentage uint))
  (let ((entry (map-get? waste-registry {hash: hash})))
    (if (and (is-some entry) (is-eq (get owner (unwrap! entry (err ERR-NOT-FOUND))) tx-sender) (<= percentage u100))
      (begin
        (map-set revenue-shares
          {hash: hash, participant: participant}
          {
            percentage: percentage,
            total-received: u0
          }
        )
        (ok true)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

;; Read-Only Functions

(define-read-only (get-waste-details (hash (buff 32)))
  (map-get? waste-registry {hash: hash})
)

(define-read-only (get-version-details (hash (buff 32)) (version uint))
  (map-get? waste-versions {hash: hash, version: version})
)

(define-read-only (get-tags (hash (buff 32)))
  (map-get? waste-tags {hash: hash})
)

(define-read-only (get-collaborator (hash (buff 32)) (collaborator principal))
  (map-get? waste-collaborators {hash: hash, collaborator: collaborator})
)

(define-read-only (get-license (hash (buff 32)) (licensee principal))
  (map-get? handling-licenses {hash: hash, licensee: licensee})
)

(define-read-only (get-status-history (hash (buff 32)) (update-id uint))
  (map-get? waste-status-history {hash: hash, update-id: update-id})
)

(define-read-only (get-revenue-share (hash (buff 32)) (participant principal))
  (map-get? revenue-shares {hash: hash, participant: participant})
)

(define-read-only (has-permission (hash (buff 32)) (user principal) (permission (string-utf8 20)))
  (let ((collab (map-get? waste-collaborators {hash: hash, collaborator: user})))
    (if (is-some collab)
      (fold check-permission (get permissions (unwrap! collab false)) false)
      false
    )
  )
)

;; Private Functions

(define-private (check-permission (perm (string-utf8 20)) (acc bool))
  (or acc (is-eq perm permission))
)

