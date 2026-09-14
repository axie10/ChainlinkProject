# Oracle Integration Patterns — Chainlink & Pyth
 
A minimal Foundry workspace that walks through **how to consume the two most common price oracles in the EVM ecosystem** — Chainlink and Pyth — first in their naive form and then hardened with the validations you would expect in a production integration.
 
The goal is not to build a protocol. It is to make the design decisions and pitfalls of each oracle **visible in code**: push vs. pull data flow, staleness, confidence intervals, and fallback strategies.
 
---
 
## Why oracles
 
Smart contracts run inside the EVM, which is deterministic and isolated by design. They cannot call an HTTP endpoint, cannot read wall-clock time, and cannot know the price of ETH on Binance. Anything a contract "knows" has to live in on-chain state.
 
An **oracle** is the infrastructure that brings off-chain data on-chain in a way a contract can safely consume. This repo focuses on **price oracles**, the workhorse of DeFi.
 
Chainlink and Pyth solve the same problem with two different architectures:
 
| | Chainlink | Pyth |
|---|---|---|
| Data flow | **Push** — node operators write updates on-chain when a deviation or heartbeat triggers | **Pull** — publishers sign prices off-chain; the consumer transaction brings the update on-chain |
| Trust model | Decentralized set of node operators aggregate a median from many sources | First-party publishers (exchanges, market makers) sign their own prices |
| Latency | Minutes | Sub-second |
| Who pays gas for updates | The feed maintainer | The transaction that consumes the price |
| Best fit | Blue-chip pairs on lending / stablecoin protocols | Perps, derivatives, long-tail assets |
 
Everything in this repo is built to make that contrast tangible.
 
---
 
## Contracts
 
Four contracts under `src/`, organized as two pairs (naive → hardened).
 
### `ChainlinkOracle.sol`
The absolute minimum: read `latestRoundData()` from an `AggregatorV3Interface` and return the price. **No validations.** Deliberately kept as a baseline so the hardened version reads clearly against it.
 
Deploy with an aggregator address; ETH/USD is used as the reference pair.
 
### `ChainlinkOracleChecks.sol`
The version you would ship. Adds:
 
- **Primary + secondary feed** with a `try/catch` fallback so a single feed outage does not brick consumers.
- **Staleness check** (`block.timestamp - updatedAt <= staleFeedThreshold`) — the failure mode Chainlink incidents actually produce is not "wrong price" but "no price update for hours".
- **Positive price** and **valid timestamp** invariants.
- **Explicit `decimals()`** returned alongside the price so consumers do not assume 8 decimals for every pair.
The `staleFeedThreshold` is deliberately a constructor parameter: each feed has its own heartbeat (ETH/USD ~1 h, stablecoins ~24 h on mainnet, different on L2s).
 
### `PythOracle.sol`
Naive Pyth consumer. Uses `getPriceUnsafe`, which is what its name suggests — it returns whatever is stored on-chain without any age check. Also exposes an `updatePrice` entrypoint that pays the Pyth update fee.
 
Included to make the difference with the checked version obvious.
 
### `PythOracleChecks.sol`
The version you would ship. Implements Pyth's documented best practices:
 
- **`getPriceNoOlderThan(priceId, MAX_AGE_SECONDS)`** instead of `getPriceUnsafe` — the safe reader that reverts on stale data.
- **In-transaction update flow**: `updatePrice(updateData)` is called first, so the freshest signed price is written on-chain before we read it. This is the canonical Pyth pull pattern.
- **Confidence interval validation** — Pyth returns a confidence band `conf` alongside each `price`. A price with a wide confidence interval means the publishers disagree or the market is halted; we reject it.
- **Exponent bound** (`expo >= -18`) so integrations do not silently break when a feed's precision changes.
- **Positive price** invariant.
---
 
## Architecture — the point of the repo
 
```
       Chainlink                                Pyth
       ─────────                                ────
 
  Node operators watch                    Publishers (Jane Street,
  Binance/Coinbase/…                      Jump, exchanges) sign
         │                                prices off-chain
         ▼                                       │
  Median aggregation                             ▼
  on Chainlink network                    Pythnet (fast off-chain
         │                                network, ~400 ms)
         ▼                                       │
  Node PUSHES update                             │  User's tx PULLS
  on-chain when deviation                        │  the signed price
  or heartbeat triggers                          ▼
         │                                On-chain verification
         ▼                                of signatures
  Consumer contract                              │
  reads latestRoundData()                        ▼
                                          Consumer contract
                                          reads getPriceNoOlderThan()
```
 
The two `*Checks` contracts show what "safe consumption" means for each architecture:
 
- For **Chainlink**, the risk profile is *staleness and feed failure* → the mitigation is *fallback feed + freshness check*.
- For **Pyth**, the risk profile is *the caller not bringing a fresh update, or a wide confidence band during volatile markets* → the mitigation is *update-then-read in the same tx + confidence-ratio check*.
---
 
## Stack
 
- **Solidity** `^0.8.35`
- **Foundry** (`forge`, `cast`, `anvil`)
- [`chainlink-brownie-contracts`](https://github.com/smartcontractkit/chainlink-brownie-contracts) for `AggregatorV3Interface`
- [`pyth-sdk-solidity`](https://github.com/pyth-network/pyth-sdk-solidity) for `IPyth` and `PythStructs`
Remappings are set in `remappings.txt`:
 
```
@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/src/
@pythnetwork/pyth-sdk-solidity/=lib/pyth-sdk-solidity
```
 
---
 
## Getting started
 
```bash
git clone https://github.com/axie10/ChainlinkProject.git
cd ChainlinkProject
 
# Install dependencies
forge install smartcontractkit/chainlink-brownie-contracts
forge install pyth-network/pyth-sdk-solidity
 
# Build
forge build
 
# Format
forge fmt
```
 
Tests are not included in this iteration — see [Roadmap](#roadmap).
 
---
 
## What this repo is deliberately *not*
 
- Not a production oracle library — the license reflects that (`UNLICENSED` on the Chainlink pair).
- Not a full protocol integration — no lending, no AMM, no consumer contract using these prices.
- Not TWAP — DEX-derived oracles are a distinct architecture and are treated as a separate topic.
---
 
## Roadmap
 
- [ ] Foundry test suite with mocked feeds (`MockV3Aggregator`, mock `IPyth`) covering staleness, feed failure, wide confidence and negative prices.
- [ ] Fork-tests against Sepolia to validate against live feeds.
- [ ] `SequencerUptimeFeed` guard for L2 deployments (Arbitrum, Optimism).
- [ ] A consumer contract that uses `ChainlinkOracleChecks` for pricing and demonstrates decimal normalization between feeds.
- [ ] TWAP oracle example (Uniswap V3 `observe()`) as a third contract pair, to close the "three architectures" story.
---
 
## License
 
See SPDX headers per contract. This repository is a learning exercise; do not deploy any of these contracts to hold real value without an audit and a proper test suite.