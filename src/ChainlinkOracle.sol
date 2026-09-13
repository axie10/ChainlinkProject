// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkOracle {
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia / Ethereum Mainnet
     * Aggregator: ETH/USD
     * Address for Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     * Address for Mainnet: 0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419
     */
    constructor(address _priceFedd) {
        priceFeed = AggregatorV3Interface(_priceFedd);
    }

    /// @dev return last price of token
    function getLastPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData(); // @audit Do not use latestAnswer()
        return price;
    }

    /// @dev return additional data: round ID, timestamp, etc
    function getRoundData()
        public
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return priceFeed.latestRoundData();
    }
}
