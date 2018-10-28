# eve
## End-to-end Verifiable Internet Voting (E2E-VIV) on Ethereum

---

### What is EVE?

EVE is an *End-to-End Verifiable-Internet-Voting* (E2E-VIV) app based on Ethereum.

It achieves:

* Privacy: No one can know how you voted.
* Verifiability: You can verify that your vote is counted in the tally.
* Trustlessness: EVE does not require a centralized tallying authority.

### How does it work?

The current implementation makes use of Enigma ([https://enigma.co/](https://enigma.co/))—a decentralized private computing platform. EVE uses Enigma to trustlessly, securely, and privately tally votes submitted to a voting smart contract.

### Why is it cooler than other similar solutions? (e.g. homomorphic crypto based ones)

* Simple infrastructure: smart contract + Enigma VS. one chain for each election etc.
* DAO compatible: can be used for DAO elections
* Highly versatile: can use any voting rule, like yes/no, 1-out-of-n, k-out-of-n, quadratic, and so on

### What's the current progress?

* Voting smart contract that registers encrypted votes and submits the votes to Enigma for tallying. Deployed onto Rinkeby.
* Simulated Enigma worker that tallies votes, implemented in JS.
* Basic front end for voting using the Rinkeby contract.

GitHub: https://github.com/ConsenSys/eve

Front end: https://gateway.ipfs.io/ipfs/QmWGyKGeTrtdvnfWX5efpisUS5YVgiyJAX5AVeLQ3vGW2p/

### What more work is needed?

* Integration with Enigma Testnet
* Move vote encoding off-chain somehow

---

### Walking through EVE

This doc will walk you through voting and tallying votes in the current EVE implementation.
Check out EVE here: https://gateway.ipfs.io/ipfs/QmWGyKGeTrtdvnfWX5efpisUS5YVgiyJAX5AVeLQ3vGW2p/

![alt text](https://github.com/ConsenSys/eve/blob/master/EVEDemoImage.png)

#### Submitting a vote

At the top of the interface, you will see your Ethereum account and whether you have already submitted a vote. You can only submit one vote per account. If you don't see your address, please make sure you have Metamask unlocked and switched to the Rinkeby Testnet.

To submit a vote, first select whether you're voting for or against the proposal. You might ask: “What proposal?” Just pretend there's a proposal you're voting on, the current EVE implementation is only for demoing the tech.

After that, click “Vote” and submit the Ethereum transaction using Metamask. You will be able to see your encrypted vote appear below. Your vote will be registered once the transaction goes through.

Tallying votes

You can calculate the current tally at any time. Just click “Tally votes & update tally (2 txs)” and submit the Ethereum transactions, and a simulated Enigma worker running in your browser will decrypt the submitted votes and calculate the tally.

(A simulated worker is only used here due to the difficulty of setting up the Enigma Testnet, it would be trivial to replace the simulated worker with a real one if you have the Testnet set up.)

Once the transactions go through, the current tally will appear, as well as the number of votes currently submitted.

---

### EVE Tech Specs

#### Stack

* Front end (https://github.com/Consensys/eve/tree/master/demo/eve-ui)
    * Web3.js + Meteor
    * Deployed at https://gateway.ipfs.io/ipfs/QmWGyKGeTrtdvnfWX5efpisUS5YVgiyJAX5AVeLQ3vGW2p
* Back end smart contracts (https://github.com/Consensys/eve/tree/master/contracts)
    * Voting: Naive voting, encodes votes on-chain
        * Used in current implementation, deployed to Rinkeby at 0xa8c00edd3eabbd00ef02451239d1fcb68102a174
    * BatchVoting: Tallies votes in batches to improve scalability, encodes votes on-chain
    * HashVoting: Only stores hash of encoded votes on-chain, calculation is moved off-chain, uses a challenge system to trustlessly encode votes
* Enigma network
    * Enigma contract deployed on Rinkeby at 0x79e137337d87729823704c023a6ba9de578799ba
    * Enigma worker (https://github.com/Consensys/eve/blob/master/demo/eve-ui/imports/body.coffee) is simulated using JS in current implementation, runs in front end

#### Voting Workflow

1. Front end encrypts vote and submits it to voting contract
2. Admin (or anyone else) calls submitVotesForTally() to tally votes
    1. Voting contract encodes votes using RLP encoding, which Enigma uses for encoding input arguments
    2. The encoded votes are then submitted to the Enigma contract using compute()
    3. Enigma contract emits event with details of the task, which can be picked up by workers
3. Worker decrypts the votes and calculates tally
    1. Worker uses the Solidity function tallyVotes() provided by the voting contract to perform the tally in its EVM (simulated)
    2. tallyVotes() ensures that only votes that are either 0 or 1 are counted in the tally
4. Worker submit tally to Enigma contract
5. Voting contract receives and updates tally in callback()
