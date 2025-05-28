;; Route Optimization Contract
;; Minimizes transportation emissions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-route-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-invalid-coordinates (err u303))
(define-constant err-invalid-vehicle (err u304))

;; Data Variables
(define-data-var next-route-id uint u1)

;; Data Maps
(define-map routes
    { route-id: uint }
    {
        origin: {lat: uint, lng: uint},
        destination: {lat: uint, lng: uint},
        waypoints: (list 20 {lat: uint, lng: uint}),
        vehicle-type: (string-ascii 20),
        estimated-distance: uint,
        estimated-emissions: uint,
        optimization-score: uint,
        created-by: principal,
        created-at: uint
    }
)

(define-map vehicle-efficiency
    { vehicle-type: (string-ascii 20) }
    { emission-factor: uint, capacity: uint }
)

(define-map optimizers
    { optimizer: principal }
    { authorized: bool }
)

;; Initialize vehicle types
(map-set vehicle-efficiency { vehicle-type: "truck" } { emission-factor: u250, capacity: u10000 })
(map-set vehicle-efficiency { vehicle-type: "van" } { emission-factor: u180, capacity: u3000 })
(map-set vehicle-efficiency { vehicle-type: "electric-truck" } { emission-factor: u50, capacity: u8000 })
(map-set vehicle-efficiency { vehicle-type: "train" } { emission-factor: u80, capacity: u50000 })

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-optimizer)
    (default-to false (get authorized (map-get? optimizers { optimizer: tx-sender })))
)

;; Admin Functions
(define-public (add-optimizer (optimizer principal))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (ok (map-set optimizers { optimizer: optimizer } { authorized: true }))
    )
)

(define-public (update-vehicle-efficiency (vehicle-type (string-ascii 20)) (emission-factor uint) (capacity uint))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (ok (map-set vehicle-efficiency { vehicle-type: vehicle-type } { emission-factor: emission-factor, capacity: capacity }))
    )
)

;; Distance Calculation (simplified Haversine approximation)
(define-private (calculate-distance (origin {lat: uint, lng: uint}) (destination {lat: uint, lng: uint}))
    (let
        (
            (lat-diff (if (> (get lat destination) (get lat origin))
                (- (get lat destination) (get lat origin))
                (- (get lat origin) (get lat destination))
            ))
            (lng-diff (if (> (get lng destination) (get lng origin))
                (- (get lng destination) (get lng origin))
                (- (get lng origin) (get lng destination))
            ))
            (approx-distance (+ (* lat-diff u111) (* lng-diff u85))) ;; Simplified km calculation
        )
        approx-distance
    )
)

;; Route Optimization Functions
(define-private (calculate-route-emissions (distance uint) (vehicle-type (string-ascii 20)))
    (match (map-get? vehicle-efficiency { vehicle-type: vehicle-type })
        vehicle-data (* distance (get emission-factor vehicle-data))
        u0
    )
)

(define-private (calculate-optimization-score (emissions uint) (distance uint) (vehicle-type (string-ascii 20)))
    (let
        (
            (efficiency-ratio (/ emissions distance))
            (vehicle-bonus (if (is-eq vehicle-type "electric-truck")
                u30
                (if (is-eq vehicle-type "train")
                    u40
                    u0
                )
            ))
        )
        (if (< efficiency-ratio u100)
            (+ u90 vehicle-bonus)
            (if (< efficiency-ratio u200)
                (+ u70 vehicle-bonus)
                (+ u50 vehicle-bonus)
            )
        )
    )
)

;; Main Optimization Function
(define-public (optimize-route (origin {lat: uint, lng: uint}) (destination {lat: uint, lng: uint}) (vehicle-type (string-ascii 20)))
    (let
        (
            (route-id (var-get next-route-id))
            (distance (calculate-distance origin destination))
            (emissions (calculate-route-emissions distance vehicle-type))
            (optimization-score (calculate-optimization-score emissions distance vehicle-type))
        )
        (asserts! (is-authorized-optimizer) err-unauthorized)
        (asserts! (is-some (map-get? vehicle-efficiency { vehicle-type: vehicle-type })) err-invalid-vehicle)
        (asserts! (and (> (get lat origin) u0) (> (get lng origin) u0)) err-invalid-coordinates)
        (asserts! (and (> (get lat destination) u0) (> (get lng destination) u0)) err-invalid-coordinates)

        (map-set routes
            { route-id: route-id }
            {
                origin: origin,
                destination: destination,
                waypoints: (list),
                vehicle-type: vehicle-type,
                estimated-distance: distance,
                estimated-emissions: emissions,
                optimization-score: optimization-score,
                created-by: tx-sender,
                created-at: block-height
            }
        )

        (var-set next-route-id (+ route-id u1))
        (ok route-id)
    )
)

;; Add Waypoints to Route
(define-public (add-route-waypoint (route-id uint) (waypoint {lat: uint, lng: uint}))
    (let
        (
            (route-data (unwrap! (map-get? routes { route-id: route-id }) err-route-not-found))
            (current-waypoints (get waypoints route-data))
            (updated-waypoints (unwrap! (as-max-len? (append current-waypoints waypoint) u20) err-invalid-coordinates))
        )
        (asserts! (is-eq tx-sender (get created-by route-data)) err-unauthorized)
        (asserts! (and (> (get lat waypoint) u0) (> (get lng waypoint) u0)) err-invalid-coordinates)

        (ok (map-set routes
            { route-id: route-id }
            (merge route-data { waypoints: updated-waypoints })
        ))
    )
)

;; Multi-modal Route Optimization
(define-public (optimize-multimodal-route (origin {lat: uint, lng: uint}) (destination {lat: uint, lng: uint}) (cargo-weight uint))
    (let
        (
            (truck-route (calculate-emissions-for-mode origin destination "truck"))
            (train-route (calculate-emissions-for-mode origin destination "train"))
            (electric-route (calculate-emissions-for-mode origin destination "electric-truck"))
            (best-option (get-best-modal-option truck-route train-route electric-route))
        )
        (asserts! (is-authorized-optimizer) err-unauthorized)
        (ok best-option)
    )
)

(define-private (calculate-emissions-for-mode (origin {lat: uint, lng: uint}) (destination {lat: uint, lng: uint}) (mode (string-ascii 20)))
    (let
        (
            (distance (calculate-distance origin destination))
            (emissions (calculate-route-emissions distance mode))
        )
        { mode: mode, distance: distance, emissions: emissions }
    )
)

(define-private (get-best-modal-option (truck {mode: (string-ascii 20), distance: uint, emissions: uint})
                                      (train {mode: (string-ascii 20), distance: uint, emissions: uint})
                                      (electric {mode: (string-ascii 20), distance: uint, emissions: uint}))
    (if (< (get emissions electric) (get emissions truck))
        (if (< (get emissions electric) (get emissions train))
            electric
            train
        )
        (if (< (get emissions truck) (get emissions train))
            truck
            train
        )
    )
)

;; Read-only Functions
(define-read-only (get-route-data (route-id uint))
    (map-get? routes { route-id: route-id })
)

(define-read-only (calculate-route-distance (origin {lat: uint, lng: uint}) (destination {lat: uint, lng: uint}))
    (calculate-distance origin destination)
)

(define-read-only (estimate-emissions (distance uint) (vehicle-type (string-ascii 20)))
    (calculate-route-emissions distance vehicle-type)
)

(define-read-only (get-vehicle-info (vehicle-type (string-ascii 20)))
    (map-get? vehicle-efficiency { vehicle-type: vehicle-type })
)

(define-read-only (get-total-routes)
    (- (var-get next-route-id) u1)
)

;; Compare vehicle options for route
(define-read-only (compare-vehicle-options (origin {lat: uint, lng: uint}) (destination {lat: uint, lng: uint}))
    (let
        (
            (distance (calculate-distance origin destination))
            (truck-emissions (calculate-route-emissions distance "truck"))
            (van-emissions (calculate-route-emissions distance "van"))
            (electric-emissions (calculate-route-emissions distance "electric-truck"))
            (train-emissions (calculate-route-emissions distance "train"))
        )
        {
            distance: distance,
            truck: truck-emissions,
            van: van-emissions,
            electric-truck: electric-emissions,
            train: train-emissions
        }
    )
)
