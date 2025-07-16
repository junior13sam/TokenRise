# TokenRise

Table of Contents
-----------------

-   TokenRise

    -   Table of Contents

    -   Introduction

    -   Features

    -   Error Codes

    -   Constants

    -   Data Structures

    -   Public Functions

    -   Private Functions

    -   Usage

    -   Deployment

    -   Contributing

    -   License

    -   Security

    -   Contact

* * * * *

Introduction
------------

`TokenRise` is a secure Clarity smart contract designed for decentralized crowdfunding and token launches on the Stacks blockchain. It enables project creators to raise funds for their initiatives and distribute tokens to backers, incorporating a robust milestone-based release system for enhanced accountability and progressive fund management. This contract facilitates transparency and trust between project creators and their communities by linking fund disbursement to the achievement of predefined milestones and community approval.

* * * * *

Features
--------

I've designed this contract with several key features:

-   **Decentralized Crowdfunding:** Projects can raise STX from backers.

-   **Token Launchpad:** Integrates token distribution to backers based on their contributions.

-   **Milestone-Based Funding Release:** Funds are released to project creators progressively upon the completion of predefined milestones.

-   **Community Validation:** An advanced system for milestone validation incorporates performance metrics and community approval thresholds for fund release.

-   **Platform Fees:** A configurable platform fee is collected for the contract owner to maintain the platform.

-   **Refund Mechanism:** Backers can claim refunds if a campaign fails to meet its funding goal.

-   **Flexible Campaign Durations:** Campaigns can be set for a minimum of 10 days and a maximum of 100 days.

* * * * *

Error Codes
-----------

| Error Code | Description |
| --- | --- |
| `u100` | `err-owner-only`: Only callable by the contract owner. |
| `u101` | `err-not-found`: Campaign or backer record not found. |
| `u102` | `err-already-exists`: Campaign already exists. (Currently unused, but reserved) |
| `u103` | `err-invalid-amount`: Invalid amount or duration provided. |
| `u104` | `err-campaign-ended`: Campaign has already ended. |
| `u105` | `err-campaign-not-ended`: Campaign has not yet ended. |
| `u106` | `err-insufficient-funds`: Insufficient funds to perform action. |
| `u107` | `err-already-claimed`: Tokens or refund already claimed, or milestone already completed. |
| `u108` | `err-milestone-not-reached`: Milestone funding threshold or approval not reached. |
| `u109` | `err-unauthorized`: Caller is not authorized for this action. |
| `u110` | `err-campaign-failed`: Campaign did not meet its funding goal. |

* * * * *

Constants
---------

-   **`contract-owner`**: The principal address of the contract deployer.

-   **`min-campaign-duration`**: Minimum campaign duration in blocks (1440 blocks = ~10 days).

-   **`max-campaign-duration`**: Maximum campaign duration in blocks (14400 blocks = ~100 days).

-   **`platform-fee-percentage`**: The percentage of funds collected as a platform fee (3% in this case).

* * * * *

Data Structures
---------------

### `campaigns` Map

Stores details for each crowdfunding campaign.

-   `campaign-id`: `uint` (Primary Key)

-   `creator`: `principal`

-   `title`: `(string-ascii 50)`

-   `description`: `(string-ascii 200)`

-   `funding-goal`: `uint`

-   `current-funding`: `uint`

-   `token-supply`: `uint`

-   `tokens-per-stx`: `uint`

-   `start-block`: `uint`

-   `end-block`: `uint`

-   `milestone-count`: `uint`

-   `milestones-completed`: `uint`

-   `is-successful`: `bool`

-   `tokens-distributed`: `bool`

-   `funds-withdrawn`: `bool`

### `campaign-backers` Map

Records contributions and token claims for each backer per campaign.

-   `campaign-id`: `uint` (Primary Key)

-   `backer`: `principal` (Primary Key)

-   `amount-contributed`: `uint`

-   `tokens-earned`: `uint`

-   `tokens-claimed`: `bool`

-   `refund-claimed`: `bool`

### `campaign-milestones` Map

Defines the milestones for each campaign.

-   `campaign-id`: `uint` (Primary Key)

-   `milestone-id`: `uint` (Primary Key)

-   `description`: `(string-ascii 100)`

-   `funding-threshold`: `uint`

-   `is-completed`: `bool`

-   `completion-block`: `uint`

### Data Variables

-   **`next-campaign-id`**: `uint` (Starts at `u1`, increments with each new campaign).

-   **`platform-treasury`**: `uint` (Accumulates platform fees).

* * * * *

Public Functions
----------------

### `create-campaign`

I designed this function to allow project creators to initiate a new crowdfunding campaign.

-   **Parameters:**

    -   `title`: `(string-ascii 50)` - Title of the campaign.

    -   `description`: `(string-ascii 200)` - Detailed description of the campaign.

    -   `funding-goal`: `uint` - Target STX amount to raise.

    -   `token-supply`: `uint` - Total supply of tokens to be distributed.

    -   `tokens-per-stx`: `uint` - Number of tokens a backer receives per STX contributed.

    -   `duration-blocks`: `uint` - Campaign duration in blocks (min 1440, max 14400).

    -   `milestone-descriptions`: `(list 5 (string-ascii 100))` - List of milestone descriptions.

    -   `milestone-thresholds`: `(list 5 uint)` - List of funding thresholds for each milestone.

-   **Returns:** `(ok uint)` on success with the `campaign-id`, or an error.

### `back-campaign`

This function allows users to contribute STX to an active campaign.

-   **Parameters:**

    -   `campaign-id`: `uint` - The ID of the campaign to back.

    -   `amount`: `uint` - The amount of STX to contribute.

-   **Returns:** `(ok uint)` on success with the `tokens-earned`, or an error.

### `claim-tokens`

Backers use this function to claim their earned tokens after a successful campaign has ended.

-   **Parameters:**

    -   `campaign-id`: `uint` - The ID of the campaign.

-   **Returns:** `(ok uint)` on success with the `tokens-earned` amount, or an error. (Note: Token minting/transfer is simulated as a return value in this demo).

### `claim-refund`

This function is for backers to claim their contributed STX if a campaign fails to reach its funding goal.

-   **Parameters:**

    -   `campaign-id`: `uint` - The ID of the campaign.

-   **Returns:** `(ok uint)` on success with the `amount-contributed` refunded, or an error.

### `withdraw-campaign-funds`

Project creators can call this function to withdraw funds upon completing a milestone.

-   **Parameters:**

    -   `campaign-id`: `uint` - The ID of the campaign.

    -   `milestone-id`: `uint` - The ID of the milestone being completed.

-   **Returns:** `(ok uint)` on success with the `creator-amount` withdrawn, or an error.

### `process-milestone-validation-and-fund-release`

I've designed this advanced function to allow project creators to process milestone validation and progressively release funds based on performance metrics and community approval.

-   **Parameters:**

    -   `campaign-id`: `uint` - The ID of the campaign.

    -   `milestone-id`: `uint` - The ID of the milestone to validate.

    -   `performance-metrics`: `(list 3 uint)` - A list of uints representing performance metrics (e.g., votes, task completion percentages) for community approval.

    -   `community-approval-threshold`: `uint` - The minimum percentage of community approval required for fund release.

-   **Returns:** `(ok { milestone-id: uint, released-amount: uint, approval-percentage: uint, bonus-applied: bool, platform-fee: uint })` on success, or an error.

* * * * *

Private Functions
-----------------

### `is-campaign-active`

Checks if a given campaign is currently active based on its start and end blocks and success status.

-   **Parameters:** `campaign-id`: `uint`

-   **Returns:** `bool`

### `calculate-tokens`

Calculates the number of tokens earned based on the STX amount and `tokens-per-stx` rate.

-   **Parameters:** `amount`: `uint`, `tokens-per-stx`: `uint`

-   **Returns:** `uint`

### `calculate-platform-fee`

Calculates the platform fee for a given amount.

-   **Parameters:** `amount`: `uint`

-   **Returns:** `uint`

### `is-funding-goal-reached`

Checks if a campaign's current funding has reached or exceeded its funding goal.

-   **Parameters:** `campaign-id`: `uint`

-   **Returns:** `bool`

### `create-milestone-entry`

A helper function used by `create-campaign` to create individual milestone entries.

-   **Parameters:** `description`: `(string-ascii 100)`, `threshold`: `uint`, `campaign-id`: `uint`, `milestone-id`: `uint`

-   **Returns:** `(response bool uint)`

### `calculate-progressive-release`

Calculates the amount of funds to release based on a base amount and an approval percentage.

-   **Parameters:** `base-amount`: `uint`, `approval-percentage`: `uint`

-   **Returns:** `uint`

### `get-campaign-backer-count`

(Simplified for demo) Retrieves the number of backers for a given campaign.

-   **Parameters:** `campaign-id`: `uint`

-   **Returns:** `uint`

* * * * *

Usage
-----

### For Project Creators

1.  **Deploy the contract:** Once the contract is deployed, you become the `contract-owner`.

2.  **Create a Campaign:** Use the `create-campaign` function, specifying your funding goal, tokenomics, campaign duration, and detailed milestones with their respective funding thresholds.

3.  **Withdraw Funds (Milestone-based):** As you complete milestones, use `withdraw-campaign-funds` to release portions of the raised STX. For advanced release, use `process-milestone-validation-and-fund-release`, incorporating performance metrics and community approval.

### For Backers

1.  **Browse Campaigns:** Identify campaigns you wish to support.

2.  **Back a Campaign:** Use the `back-campaign` function, specifying the `campaign-id` and the amount of STX you wish to contribute. You will earn tokens based on the campaign's `tokens-per-stx` rate.

3.  **Claim Tokens:** If the campaign is successful and has ended, use `claim-tokens` to claim your earned project tokens.

4.  **Claim Refund:** If a campaign fails to reach its funding goal by its `end-block`, use `claim-refund` to retrieve your contributed STX.

* * * * *

Deployment
----------

This contract is written in Clarity and can be deployed on the Stacks blockchain. You will need a Stacks wallet and sufficient STX for gas fees. I recommend using the Stacks.js library or a similar development environment for deployment.

* * * * *

Contributing
------------

I welcome contributions to enhance `TokenRise`! If you have suggestions for improvements, find bugs, or want to add new features, please feel free to:

1.  Fork the repository.

2.  Create a new branch (`git checkout -b feature/YourFeature`).

3.  Make your changes.

4.  Commit your changes (`git commit -am 'Add new feature'`).

5.  Push to the branch (`git push origin feature/YourFeature`).

6.  Create a new Pull Request.

* * * * *

License
-------

This contract is released under the MIT License. See the `LICENSE` file in the repository for full details.

* * * * *

Security
--------

I've implemented `TokenRise` with security in mind, including checks for sender authorization, campaign states, and sufficient funds. However, smart contracts are complex, and new vulnerabilities can emerge. I strongly recommend:

-   **Independent Audits:** Before using this contract for significant value, consider a professional security audit.

-   **Thorough Testing:** Conduct extensive testing in various scenarios.

-   **Bug Bounties:** Consider setting up a bug bounty program if you plan to use this contract in a production environment.

* * * * *

Contact
-------

If you have any questions or need further assistance with `TokenRise`, please reach out to me.
