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
        
  - *Chainlink automation*
      - Chainlink automation is important part of stake N Bake.
      - Stake N Bake utilizes automation for triggering state changes across chains & for timely distribution of staking rewards.

  - *Chainlink CCIP*
      - Stake N' Bake is cross-chain game and allows users to play game across the chains.
      - We utilize CCIP for cross chain messaging from users source chain to destination chain.
      - It involves cross chain messaging from source to destination and performing specific functions upon receiving a cross chain message.

### How we built it
      - Stake N' Bake is combination of cross-chain and gameFi. 
      - This combines gaming features that are expected from a gameFi project to make it more interactive and enjoyable Also enabling cross chain features to allow cross-            chain gaming experience. 
      - We have utilized whole suite of chainlink tools with developer tools like Thirdweb SDK, Amazon AWS Lambda, and other tools.
      - The combination of this tools are powering the Stake N Bake from under the hood.
      - Not only technical implementation but good product research is kept in mind while coming up with this idea. 
      
### Challenges faced
      - Challenges are part of building and are symbol of progress.
      - As we were integrating chainlink and other tools in Stake N Bake we faced hurdles with implementation, performance and debugging various functions.
      - Challenges mainly revolved around enhancing performance and utilizing tools correctly to ensure good performance.
      - To resolve the issues we faced, We have got constant support from chainlink and other communities. 

### Accomplishments We're Proud Of
      - We are proud of the features that we have built to make Stake N Bake enjoyable and interesting.
      - Though we have achieved major features that we visioned but we look forward to fill in the gaps for improvment.
      - We take pride in being one of the first gameFi projects to be in cross-chain gameFi space.
