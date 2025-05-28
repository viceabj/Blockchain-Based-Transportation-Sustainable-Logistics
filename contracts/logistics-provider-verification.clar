;; Sustainability Assessment Contract
;; Evaluates logistics environmental impact

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-assessment-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-data (err u203))

;; Data Variables
(define-data-var next-assessment-id uint u1)
(define-data-var carbon-factor-road uint u250) ;; grams CO2 per km
(define-data-var carbon-factor-rail uint u80)  ;; grams CO2 per km
(define-data-var carbon-factor-sea uint u15)   ;; grams CO2 per km

;; Data Maps
(define-map assessments
    { assessment-id: uint }
    {
        provider-id: uint,
        distance-km: uint,
        cargo-weight-kg: uint,
        transport-mode: (string-ascii 20),
        carbon-emissions: uint,
        sustainability-score: uint,
        assessor: principal,
        created-at: uint
    }
)

(define-map provider-assessments
    { provider-id: uint }
    { assessment-ids: (list 100 uint) }
)

(define-map assessors
    { assessor: principal }
    { authorized: bool }
)

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-assessor)
    (default-to false (get authorized (map-get? assessors { assessor: tx-sender })))
)

;; Admin Functions
(define-public (add-assessor (assessor principal))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (ok (map-set assessors { assessor: assessor } { authorized: true }))
    )
)

(define-public (update-carbon-factors (road uint) (rail uint) (sea uint))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (var-set carbon-factor-road road)
        (var-set carbon-factor-rail rail)
        (var-set carbon-factor-sea sea)
        (ok true)
    )
)

;; Carbon Calculation Functions
(define-private (calculate-carbon-emissions (distance uint) (weight uint) (mode (string-ascii 20)))
    (let
        (
            (base-factor (if (is-eq mode "road")
                (var-get carbon-factor-road)
                (if (is-eq mode "rail")
                    (var-get carbon-factor-rail)
                    (var-get carbon-factor-sea)
                )
            ))
            (weight-multiplier (+ u100 (/ weight u100))) ;; 1% increase per 100kg
        )
        (/ (* distance base-factor weight-multiplier) u100)
    )
)

(define-private (calculate-sustainability-score (emissions uint) (distance uint) (mode (string-ascii 20)))
    (let
        (
            (efficiency (/ emissions distance))
            (mode-bonus (if (is-eq mode "rail")
                u20
                (if (is-eq mode "sea")
                    u30
                    u0
                )
            ))
        )
        (if (< efficiency u100)
            (+ u80 mode-bonus)
            (if (< efficiency u200)
                (+ u60 mode-bonus)
                (+ u40 mode-bonus)
            )
        )
    )
)

;; Assessment Functions
(define-public (assess-environmental-impact (provider-id uint) (distance-km uint) (cargo-weight-kg uint) (transport-mode (string-ascii 20)))
    (let
        (
            (assessment-id (var-get next-assessment-id))
            (carbon-emissions (calculate-carbon-emissions distance-km cargo-weight-kg transport-mode))
            (sustainability-score (calculate-sustainability-score carbon-emissions distance-km transport-mode))
            (current-assessments (default-to (list) (get assessment-ids (map-get? provider-assessments { provider-id: provider-id }))))
        )
        (asserts! (is-authorized-assessor) err-unauthorized)
        (asserts! (> distance-km u0) err-invalid-data)
        (asserts! (> cargo-weight-kg u0) err-invalid-data)

        ;; Store assessment
        (map-set assessments
            { assessment-id: assessment-id }
            {
                provider-id: provider-id,
                distance-km: distance-km,
                cargo-weight-kg: cargo-weight-kg,
                transport-mode: transport-mode,
                carbon-emissions: carbon-emissions,
                sustainability-score: sustainability-score,
                assessor: tx-sender,
                created-at: block-height
            }
        )

        ;; Update provider assessments list
        (map-set provider-assessments
            { provider-id: provider-id }
            { assessment-ids: (unwrap! (as-max-len? (append current-assessments assessment-id) u100) err-invalid-data) }
        )

        (var-set next-assessment-id (+ assessment-id u1))
        (ok assessment-id)
    )
)

;; Batch Assessment
(define-public (assess-multiple-routes (provider-id uint) (routes (list 10 {distance: uint, weight: uint, mode: (string-ascii 20)})))
    (let
        (
            (assessment-results (map process-single-route routes))
        )
        (asserts! (is-authorized-assessor) err-unauthorized)
        (ok assessment-results)
    )
)

(define-private (process-single-route (route {distance: uint, weight: uint, mode: (string-ascii 20)}))
    (calculate-carbon-emissions (get distance route) (get weight route) (get mode route))
)

;; Read-only Functions
(define-read-only (get-assessment-data (assessment-id uint))
    (map-get? assessments { assessment-id: assessment-id })
)

(define-read-only (get-provider-assessments (provider-id uint))
    (map-get? provider-assessments { provider-id: provider-id })
)

(define-read-only (calculate-carbon-footprint (distance uint) (weight uint) (mode (string-ascii 20)))
    (calculate-carbon-emissions distance weight mode)
)

(define-read-only (get-carbon-factors)
    {
        road: (var-get carbon-factor-road),
        rail: (var-get carbon-factor-rail),
        sea: (var-get carbon-factor-sea)
    }
)

(define-read-only (get-total-assessments)
    (- (var-get next-assessment-id) u1)
)

;; Calculate aggregate sustainability metrics
(define-read-only (get-provider-sustainability-summary (provider-id uint))
    (match (map-get? provider-assessments { provider-id: provider-id })
        assessment-data
        (let
            (
                (assessment-ids (get assessment-ids assessment-data))
                (total-assessments (len assessment-ids))
            )
            (some {
                total-assessments: total-assessments,
                provider-id: provider-id
            })
        )
        none
    )
)
