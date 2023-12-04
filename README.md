# STAKE N' BAKE
![Stake_N_Bake](https://github.com/Rushikesh0125/Chainlink-constellation/assets/85375791/f57cd8d0-accf-4b4d-8120-f6e80f0ac120)
## Chainlink-Constellation-Submission
### Brief
  - Stake N' Bake is an omni-chain game.
  - We aim to unify GameFi and Omni-chain technology together by enabling users to play and enjoy game across multiple chains.
  - We target two major mindsets that are chain loyalists and chain hoppers.
  - The game offers amazing features like cross-chain staking, cross-chain raiding, and other amazing features.
  - The variable APR for stakers make chain hoppers to stake buds across multiple chains.
  - While raiding on stake pools is another feature to cater and entertain chain loyalist to prove there supremacy over other chains.

### How Chainlink tools serve the needs of Stake N' Bake ?

  - *Chainlink VRF*
      - Stake N Bake has various elements where probabilistic functions are needed.
      - Such functions need non-deterministic random values.
      - VRF is most secure RNG provider and we have utilized it for RNG needs of Stake N Bake.
      - Stake N' Bake raiding mechanism is based on probability and a raid is succeded 2-3 times out of 10.
        
  - *Chainlink Oracle Functions*
      - Stake N Bake is omni-chain and is deployed on multiple chains.
      - Few important state variables like global liquidity combining all chains needed to be updated across the chains.
      - We have automated this with combination of Amazon AWS lambda and chainlink oracle functions.
      - Our custom lambda endpoint gathers state from all chiains and with help of chainlink functions and automation we update state across chains.
        
  - *Chainlink automation*
      - Chainlink automation is important part of stake N Bake.
      - Stake N Bake utilizes automation for triggering state changes across chains & for timely distribution of staking rewards.

  - *Chainlink CCIP*
      - Stake N' Bake is omni-chain game and allows users to play game across the chains.
      - We utilize CCIP for cross chain messaging from users source chain to destination chain.
      - It involves cross chain messaging from source to destination and performing specific functions upon receiving a cross chain message.