# Fraktr

## Overview

Fraktr is a decentralized fractional real estate ownership platform written in Clarity. It allows properties to be tokenized into fractional ownership shares, enabling investors to purchase property tokens, earn passive income from rental or operational revenue, and participate in governance through voting on property-related proposals.

## Features

* **Property Tokenization**: Register real estate properties as tokenized assets with defined supply and token price.
* **Token Purchase**: Investors can purchase fractional ownership tokens using STX, tracked individually per property.
* **Revenue Distribution**: Property admins can deposit rental or operational revenue, which is distributed proportionally among token holders.
* **Automated Income Claims**: Token holders can withdraw their accumulated revenue at any time.
* **Governance System**: Property owners and investors can submit and vote on proposals regarding property management or investment strategies.
* **Quorum and Thresholds**: Proposals require minimum participation and majority approval to execute.

## Key Components

* **property-registry**: Stores metadata for each registered property such as name, location, total supply, and price per token.
* **token-balances**: Tracks the number of tokens held by each investor for each property.
* **token-supply**: Records the total amount of tokens issued for each property.
* **revenue-pool**: Manages the total and per-token revenue available for distribution.
* **claim-history**: Logs each investor’s claimed revenue to prevent duplicate claims.
* **governance-registry**: Holds proposals created for specific properties, including their descriptions, vote counts, and execution status.
* **voting-records**: Tracks each voter’s participation and vote weight for proposals.

## Error Codes

* `ERR-UNAUTHORIZED`: Action restricted to contract or property admin.
* `ERR-NOT-FOUND`: Property, token, or proposal does not exist.
* `ERR-INVALID-INPUT`: Input parameters are invalid or empty.
* `ERR-INACTIVE-PROPERTY`: The property is no longer active.
* `ERR-INSUFFICIENT-BALANCE`: Insufficient tokens or STX balance for the operation.
* `ERR-NO-INCOME-AVAILABLE`: No unclaimed revenue is available.
* `ERR-VOTING-ENDED`: Voting period has already expired.
* `ERR-VOTING-IN-PROGRESS`: Voting is still ongoing.
* `ERR-PROPOSAL-FAILED`: Proposal did not meet quorum or approval requirements.
* `ERR-ALREADY-EXECUTED`: Proposal has already been executed.

## Functions Summary

* **register-property**: Registers a new property and initializes related maps.
* **purchase-tokens**: Allows users to buy fractional ownership tokens for a property.
* **deposit-revenue**: Property admin deposits property income for token holders.
* **withdraw-revenue**: Token holders claim their proportional share of distributed income.
* **submit-proposal**: Creates a new governance proposal for a property.
* **cast-vote**: Allows token holders to vote for or against a proposal.
* **execute-proposal**: Executes approved proposals meeting quorum and majority thresholds.
* **get-property-info**: Retrieves details of a specific property.
* **get-token-balance**: Returns token balance for an investor.
* **get-proposal-info**: Fetches proposal data for a property.
* **calculate-claimable**: Calculates how much revenue an investor can claim.
* **get-properties-count**: Returns the total number of registered properties.

## Governance Parameters

* **Proposal Creation Threshold**: At least 5% of total property tokens required.
* **Voting Quorum**: Minimum of 10% total token participation required.
* **Majority Rule**: Proposals pass when yes-votes exceed no-votes after quorum is met.

## Initialization

* Property IDs start from `u1` and increment automatically.
* Each property initializes its own revenue pool, token supply tracker, and governance counter.
