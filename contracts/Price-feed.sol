// SPDX-License-Identifier: MIT
// Commodity Contract for Chainlink Hackathon 2022
// This smart contract is designed to use commodities pricing from off-chain sources
// It is using Chainlink commodities aggregation for WTI Oil, Gold, & Silver
// It is running in Remix over the ETH MainNet

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed_WTI;
    AggregatorV3Interface internal priceFeed_GOLD;
    AggregatorV3Interface internal priceFeed_SILVER;

    /**
     * Network: ETH Mainnet Required for LINK Commodities
     * Aggregator1: WTI/USD
     * Aggregator2: Gold/USD
     * Aggregator3: Silver/USD
     * Kovan Test ETH Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
     */
    constructor() public {
        // price feed 1 WTI Oil
        priceFeed_WTI = AggregatorV3Interface(0xf3584F4dd3b467e73C2339EfD008665a70A4185c);
        // price feed 2 Gold
        priceFeed_GOLD = AggregatorV3Interface(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
        // price feed 3 Silver
        priceFeed_SILVER = AggregatorV3Interface(0x379589227b15F1a12195D3f2d90bBc9F31f95235);
    }

    /**
     * Returns the latest price
     * Variable warnings in Remix are fields that popuate from the feed
     */
    function getLatestPrice()
        public
        view
        returns (
            /*string calldata commodityName*/
            int256
        )
    {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed_WTI.latestRoundData();
        return price;
    }
} // end contract.