# Blockchain-Based Transportation Sustainable Logistics

This project implements a blockchain-based system for sustainable logistics using Clarity smart contracts on the Stacks blockchain. The system aims to promote and track sustainable practices in the transportation and logistics industry.

## Overview

The system consists of five main smart contracts:

1. **Logistics Provider Verification**: Validates transportation companies and maintains a registry of verified providers.
2. **Sustainability Assessment**: Evaluates the environmental impact of logistics operations.
3. **Route Optimization**: Tracks optimized routes to minimize transportation emissions.
4. **Modal Shift**: Promotes the use of sustainable transportation modes.
5. **Performance Tracking**: Monitors and reports on sustainable logistics progress.

## Smart Contracts

### Logistics Provider Verification

This contract maintains a registry of verified logistics providers. Only verified providers can interact with the other contracts in the system.

Key functions:
- `register-provider`: Allows a logistics company to register in the system
- `verify-provider`: Allows the admin to verify a registered provider
- `is-verified`: Checks if a provider is verified
- `get-provider-details`: Retrieves details about a registered provider

### Sustainability Assessment

This contract evaluates the environmental impact of logistics operations based on carbon footprint, renewable energy usage, and waste reduction.

Key functions:
- `submit-assessment`: Allows a verified provider to submit sustainability data
- `get-sustainability-score`: Retrieves a provider's sustainability score
- `meets-standards`: Checks if a provider meets minimum sustainability standards

### Route Optimization

This contract tracks optimized routes to minimize transportation emissions.

Key functions:
- `register-route`: Allows a verified provider to register an optimized route
- `get-route-details`: Retrieves details about a specific route
- `get-total-emissions`: Calculates the total emissions for a provider

### Modal Shift

This contract promotes the use of sustainable transportation modes by tracking and incentivizing shifts to greener options.

Key functions:
- `update-transport-mode`: Allows a provider to update their transportation mode
- `is-using-sustainable-mode`: Checks if a provider is
