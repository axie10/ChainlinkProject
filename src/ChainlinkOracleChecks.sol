// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

//! It is important know where we deploy, L1 and L2 have different price feed and each price feed can have different decimals
//! It is important than stable coin not assume that value is 1$

contract ChainlinkOracleChecks {
    // Use two oracles for get price, secondary is used if primary failed
    AggregatorV3Interface public immutable primaryPriceFeed;
    AggregatorV3Interface public immutable secondaryPriceFeed;
    // time actualization of tokens, it is different for each token
    uint256 public immutable staleFeedThreshold; // in seconds

    constructor(address _primaryFeed, address _secondaryFeed, uint256 _staleThreshold) {
        require(_primaryFeed != address(0), "Primary feed address required");
        require(_secondaryFeed != address(0), "Secondary feed address required");
        require(_staleThreshold > 0, "Stale threshold must be positive");

        primaryPriceFeed = AggregatorV3Interface(_primaryFeed);
        secondaryPriceFeed = AggregatorV3Interface(_secondaryFeed);
        staleFeedThreshold = _staleThreshold;
    }

    function getLatestPrice() external view returns (int256 price, uint8 decimals) {
        try primaryPriceFeed.latestRoundData() {
            (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
                primaryPriceFeed.latestRoundData();

            require(answer > 0, "Primary feed: price <= 0");
            require(updatedAt > 0, "Primary feed: invalid timestamp");
            require(block.timestamp - updatedAt <= staleFeedThreshold, "Primary feed: stale");

            price = answer;
            decimals = primaryPriceFeed.decimals();
        } catch {
            try secondaryPriceFeed.latestRoundData() {
                (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
                    secondaryPriceFeed.latestRoundData();

                require(answer > 0, "Secondary feed: price <= 0");
                require(updatedAt > 0, "Secondary feed: invalid timestamp");
                require(block.timestamp - updatedAt <= staleFeedThreshold, "Secondary feed: stale");

                price = answer;
                decimals = secondaryPriceFeed.decimals();
            } catch {
                revert("Both price feeds failed");
            }
        }
    }
}
