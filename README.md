# Stake n' Bake
![Stake_N_Bake](https://github.com/Rushikesh0125/Chainlink-constellation/assets/85375791/f57cd8d0-accf-4b4d-8120-f6e80f0ac120)
## Chainlink-Constellation-Submission
### Brief
  - Stake N' Bake is an cross-chain game.
  - We aim to unify GameFi and cross-chain technology together by enabling users to play and enjoy game across multiple chains.
  - We target two major user bases that are chain loyalists and chain hoppers.
  - The game offers features like cross-chain staking, cross-chain raiding, and other features.
  - The variable APR for stakers make chain hoppers to stake buds across multiple chains.
  - While raiding on stake pools is another feature to cater and entertain chain loyalist to prove there supremacy over other chains.

### How Chainlink tools serve the needs of Stake N' Bake ?

  - *Chainlink VRF*
      - Stake N Bake has various elements where probabilistic functions are needed.
      - Such functions need non-deterministic random values.
      - VRF is most secure RNG provider and we have utilized it for RNG needs of Stake N Bake.
      - Stake N' Bake raiding mechanism is based on probability and a raid is succeded 2-3 times out of 10.
        
  - *Chainlink Oracle Functions*
      - Stake N Bake is cross-chain and is deployed on multiple chains.
      - Few important state variables like global liquidity combining all chains needed to be updated across the chains.
      - We have automated this with combination of Amazon AWS lambda and chainlink oracle functions.
      - Our custom lambda endpoint gathers state from all chains and with help of chainlink functions and automation we update state across chains.
        
  - *Chainlink Automation*
      - Chainlink automation is important part of stake N Bake.
      - Stake N Bake utilizes automation for triggering state changes across chains & for timely distribution of staking rewards.

  - *Chainlink CCIP*
      - Stake N' Bake is cross-chain game and allows users to play game across the chains.
      - We utilize CCIP for cross chain messaging from users source chain to destination chain.
      - It involves cross chain messaging from source to destination and performing specific functions upon receiving a cross chain message.

### Team Insights from the Hackathon 

  - We faced hurdles in the implementation, performance, and debugging of various functions. But it was nothing that put us to a stop and the Chainlink team was always helpful.
  - The hackathon gave us a chance to iterate on the product market fit of our idea and makes us proud of the features that we have built to make Stake N Bake unique and exciting.
  - Though we have achieved major milestones, we are eager to experiment with new infra to enhance the UX. As of now we have added gasless smart wallets, but we are determined to innovate to a point where the entire waiting time is abstracted away for cross chain 
  transactions.


