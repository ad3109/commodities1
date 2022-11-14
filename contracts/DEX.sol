// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Deposit and withdraw liquidity not working as of now

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract DEX is Ownable {

    using SafeMath for uint256; // not required for current version of solidity
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // could use mapping 
    address[] public supportedTokens;

    // struct to store amount of tokens in a particular liquidity pool
    struct lpAmounts {
        uint256 tokenA;
        uint256 tokenB;
    }

    // mapping to link token address and names
    mapping(address => string) public tokenAddressToName;

    // mapping to link token to its available liquidity
    mapping(address => uint256) public tokenAddressToLiquidity;

    // mapping to link liquidity provider address to token wise total liquidity provided
    mapping(address => mapping(address => uint256)) liquidityProviderToLiquidityProvided;

    // mapping to track available liquidity pools and th
    mapping (address => mapping(address => lpAmounts)) public liquidityPoolToAvailableLiquidity;

    event newTokenSupported(address _tokenAddress, string _tokenName, string _tokenSymbol);
    // emits tokens address and final amounts of individual tokens in pool
    event liquidityAdded(address _tokenA, address _tokenB, uint256 _tokenAAmount, uint256 tokenBAmount);
    event liquidityRemoved(address _tokenA, address _tokenB, uint256 _tokenAAmount, uint256 tokenBAmount);


    constructor() {}


    // tokens are initialized only when LP for the token is created will have to call for WETH
    function initToken(address _token) public onlyOwner returns(bool) {
        require(_token != address(0), "Enter valid address!");
        ERC20 token = ERC20(_token);
        supportedTokens.push(_token);
        tokenAddressToName[_token] = token.name();
        emit newTokenSupported(_token, token.name(), token.symbol());
        return true;
    }


    // function to initialize WETH/ERC20 pools returns number of tokens to be supplied by user in wei
    // price calculation can be done in frontend
    function addLiquidityETH(
        address _token, 
        uint256 _ethPriceUSD, 
        uint256 _tokenPriceUSD) 
    public payable returns(uint256) {
        require(_token != address(0), "Enter valid address!");
        require(msg.value >= 0, "Enter valid ETH amount!");
        ERC20 token = ERC20(_token);
       
        // if pool doesnt exist
        if( keccak256(abi.encodePacked(tokenAddressToName[_token])) == keccak256(abi.encodePacked("")) ) {
            require(initToken(_token), "Unable to add token!"); 
            uint256 ethValueUSD = msg.value.mul(_ethPriceUSD);
            uint256 deltaToken = ethValueUSD.div(_tokenPriceUSD);
            require(token.balanceOf(msg.sender) >= deltaToken);
            require(token.transferFrom(msg.sender, address(this), deltaToken), "Token transfer failed!");

            tokenAddressToLiquidity[WETH] = msg.value;
            tokenAddressToLiquidity[_token] = deltaToken;

            liquidityProviderToLiquidityProvided[msg.sender][_token] = liquidityProviderToLiquidityProvided[msg.sender][_token].add(deltaToken);
            liquidityProviderToLiquidityProvided[msg.sender][WETH] = liquidityProviderToLiquidityProvided[msg.sender][WETH].add(msg.value);

            lpAmounts memory amounts = lpAmounts(msg.value, deltaToken);
            liquidityPoolToAvailableLiquidity[WETH][_token] = amounts;

            emit liquidityAdded(WETH, _token, amounts.tokenA, amounts.tokenB);
            return deltaToken;   
        } 
        // if pool already exists
        else {
            lpAmounts memory amounts = liquidityPoolToAvailableLiquidity[WETH][_token];
            //uint256 ethReserves = address(this).balance.sub(msg.value);
            uint256 ethReserves = amounts.tokenA;
            uint256 tokenReserves = token.balanceOf(address(this));
            uint256 poolRatio = (ethReserves.mul(10 ** 18)).div(tokenReserves);

            //uint256 deltaToken = (((ethReserves + msg.value).mul(poolRatio)).div(10 ** 18)).sub(tokenReserves);
            uint256 termOne = (((ethReserves + msg.value) * (poolRatio)) / (10 ** 18));
            uint256 deltaToken = termOne > tokenReserves ? termOne - tokenReserves : tokenReserves - termOne;

            emit liquidityAdded(WETH, _token, amounts.tokenA, amounts.tokenB);
            return deltaToken;          
        }
    }


    // function to remove liquidity from eth pools
    function removeLiquidityETH(
        address _token, 
        uint256 _ethAmount, 
        uint256 _tokenAmount) 
    public returns(uint256, uint256) {

        require(_token != address(0), "Enter valid address!");
        ERC20 token = ERC20(_token);

        lpAmounts memory poolAmounts = liquidityPoolToAvailableLiquidity[WETH][_token];
        require((poolAmounts.tokenA != 0 && poolAmounts.tokenB != 0), "No liquidity for this pool");

        require(liquidityProviderToLiquidityProvided[msg.sender][WETH] >= _ethAmount, "You have not provided this much liquidity for eth!");
        require(liquidityProviderToLiquidityProvided[msg.sender][_token] >= _tokenAmount, "You have not provided this much liquidity for token!");

        liquidityPoolToAvailableLiquidity[msg.sender][WETH] = liquidityPoolToAvailableLiquidity[msg.sender][WETH].sub(_ethAmount);
        liquidityPoolToAvailableLiquidity[msg.sender][_token] = liquidityPoolToAvailableLiquidity[msg.sender][_token].sub(_tokenAmount);

        lpAmounts memory amounts = liquidityPoolToAvailableLiquidity[WETH][_token];
        amounts.tokenA = amounts.tokenA.sub(_ethAmount);
        amounts.tokenB = amounts.tokenB.sub(_tokenAmount);
        liquidityPoolToAvailableLiquidity[WETH][_token] = amounts;

        tokenAddressToLiquidity[WETH] = tokenAddressToLiquidity[WETH].sub(_ethAmount);
        tokenAddressToLiquidity[_token] = tokenAddressToLiquidity[_token].sub(_tokenAmount;

        msg.sender.transfer(_ethAmount);
        require(token.transfer(msg.sender, _tokenAmount));

        emit liquidityRemoved(WETH, _token, amounts.tokenA, amounts.tokenB);
        return (_ethAmount, _tokenAmount)
    }


    // function to calculate price to swap based on AMM
    function getSwapPrice(
        uint256 xInput, 
        uint256 xReserves, 
        uint256 yReserves) 
    public pure returns(uint256 yOutput) {
        uint256 xInputWithFee = xInput.mul(997);
        uint256 numerator = xInputWithFee.mul(yReserves);
        uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);
        return (numerator / denominator);
        // using 997 in numerator and 1000 in denominator is incorporating fee
        // yOuput = ((xInput * yReserves) / xReserves); logically this is what is going on rest is added for fees
    }


    // swap function 
    function ethToToken(address _token) public payable returns (uint256) {
        require(_token != address(0), "Enter valid address!");
        require(msg.value >= 0, "Enter valid ETH amount!");
        ERC20 token = ERC20(_token);

        lpAmounts memory amounts = liquidityPoolToAvailableLiquidity[WETH][_token];
        
        uint256 ethReserv = amounts.tokenA;
        uint256 tokenReserves = amounts.tokenB;
        uint256 tokensBought = getSwapPrice(msg.value, ethReserv, tokenReserves);

        tokenAddressToLiquidity[_token] = tokenAddressToLiquidity[_token].sub(tokensBought);

        lpAmounts memory amounts = liquidityPoolToAvailableLiquidity[WETH][_token];
        amounts.tokenA = amounts.tokenA.add(msg.value);
        amounts.tokenB = amounts.tokenB.sub(tokensBought);
        liquidityPoolToAvailableLiquidity[WETH][_token] = amounts;

        require(token.transfer(msg.sender, tokensBought), "ETH to Token swap failed!");
        return tokensBought;
    }


    function tokenToEth(address _token, uint256 _tokenAmount) public returns (uint256) {
        require(_token != address(0), "Enter valid address!");
        ERC20 token = ERC20(_token);

        lpAmounts memory amounts = liquidityPoolToAvailableLiquidity[WETH][_token];
        
        uint256 ethReserv = amounts.tokenA;
        uint256 tokenReserves = amounts.tokenB;

        uint256 ethBought = getSwapPrice(_tokenAmount, tokenReserves, ethReserv);
        payable(msg.sender).transfer(ethBought);

        lpAmounts memory amounts = liquidityPoolToAvailableLiquidity[WETH][_token];
        amounts.tokenA = amounts.tokenA.sub(ethBought);
        amounts.tokenB = amounts.tokenB.add(_tokenAmount);
        liquidityPoolToAvailableLiquidity[WETH][_token] = amounts;

        require(token.transferFrom(msg.sender, address(this), _tokenAmount), "Token to ETH swap failed to send tokens!");
        return ethBought;
    }
}
