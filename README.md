# eve
End-to-end Verifiable Internet Voting (E2E-VIV) on Ethereum

EVE TL;DR

What is EVE?

EVE is an *End-to-End Verifiable-Internet-Voting* (E2E-VIV) app based on Ethereum.

It achieves:

* Privacy: No one can know how you voted.
* Verifiability: You can verify that your vote is counted in the tally.
* Trustlessness: EVE does not require a centralized tallying authority.

How does it work?

The current implementation makes use of Enigma (https://enigma.co/)—a decentralized private computing platform. EVE uses Enigma to trustlessly, securely, and privately tally votes submitted to a voting smart contract.

Why is it cooler than other similar solutions? (e.g. homomorphic crypto based ones)

* Simple infrastructure: smart contract + Enigma VS. one chain for each election etc.
* DAO compatible: can be used for DAO elections
* Highly versatile: can use any voting rule, like yes/no, 1-out-of-n, k-out-of-n, quadratic, and so on

What's the current progress?

* Voting smart contract that registers encrypted votes and submits the votes to Enigma for tallying. Deployed onto Rinkeby.
* Simulated Enigma worker that tallies votes, implemented in JS.
* Basic front end for voting using the Rinkeby contract.

GitHub: https://github.com/ConsenSys/eve
Front end: https://gateway.ipfs.io/ipfs/QmWGyKGeTrtdvnfWX5efpisUS5YVgiyJAX5AVeLQ3vGW2p/

What more work is needed?

* Integration with Enigma Testnet
* Move vote encoding off-chain somehow

