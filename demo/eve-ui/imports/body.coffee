import "./body.html"
import { ReactiveVar } from 'meteor/reactive-var'

VOTING_ADDRESS = "0xa8c00edd3eabbd00ef02451239d1fcb68102a174"
ENIGMA_ADDRESS = "0x79e137337d87729823704c023a6ba9de578799ba"

Web3 = require "web3"
web3 = window.web3
web3 = new Web3(web3.currentProvider)

votingABI = require "./abi/Voting.json"
votingContract = new web3.eth.Contract(votingABI, VOTING_ADDRESS)
engABI = require "./abi/Enigma.json"
engContract = new web3.eth.Contract(engABI, ENIGMA_ADDRESS)

tally = new ReactiveVar(0)
vote = new ReactiveVar("")
numVotes = new ReactiveVar(0)
hasVoted = new ReactiveVar(false)
userAddress = new ReactiveVar("")

engUtils = require "./enigma-utils.js"
rlp = require "rlp"

clientPrivKey = "853ee410aa4e7840ca8948b8a2f67e9a1c2f4988ff5f4ec7794edf57be421ae5"
enclavePubKey = "0061d93b5412c0c99c3c7867db13c4e13e51292bd52565d002ecf845bb0cfd8adfa5459173364ea8aff3fe24054cca88581f6c3c5e928097b9d4d47fce12ae47"
derivedKey = engUtils.getDerivedKey(enclavePubKey, clientPrivKey)


removeLeadingZeroes = (x) ->
    while x.slice(0, 1) == "0"
        x = x.slice(1)
    return x


submitVote = (_vote) ->
    # encrypt vote
    encryptedVote = engUtils.encryptMessage(derivedKey, _vote)
    console.log "Your unprefixed encrypted vote is #{encryptedVote}"

    # add prefix padding
    prefix = "0x"
    for i in [encryptedVote.length..63]
        prefix += "0"
    encryptedVote = prefix + encryptedVote
    vote.set(encryptedVote)
    console.log "Your encrypted vote is #{encryptedVote}"

    # audit submitted vote
    voteID = await votingContract.methods.vote(encryptedVote).call()
    await votingContract.methods.vote(encryptedVote).send({ from: web3.eth.defaultAccount })
    submittedVote = await votingContract.methods.votes(voteID).call()
    console.log "Your submitted vote is #{submittedVote}, which is#{if submittedVote == encryptedVote then "" else "not"} equal to your original vote"


tallyVotes = () ->
    # submit votes to Enigma
    await votingContract.methods.submitVotesForTally().send({ from: web3.eth.defaultAccount })

    events = await engContract.getPastEvents("ComputeTask",
        fromBlock: 0
    )
    input = events[events.length - 1].returnValues.callableArgs
    console.log "Fetched encrypted input: #{input}"

    # decode data
    rawVotes = rlp.decode(input)
    votes = rawVotes[0]
    console.log "Encrypted votes: " + votes
    numVotes.set(votes.length)

    # decrypt votes
    for i in [0..votes.length - 1]
        votes[i] = engUtils.decryptMessage(derivedKey, removeLeadingZeroes(votes[i].toString("hex")))

    console.log "Decrypted votes: #{votes}"

    # tally votes
    calculatedTally = await votingContract.methods._tallyVotes(votes).call()
    console.log "Tallied votes, result is #{calculatedTally[0]}"

    # update voting contract callback
    await votingContract.methods._callback(calculatedTally[0], calculatedTally[1]).send({ from: web3.eth.defaultAccount })

    # check tally
    tally.set(await votingContract.methods.tally().call())
    console.log "Tally submitted to the voting contract is #{tally.get()}"


getCurrentTally = () ->
    events = await engContract.getPastEvents("ComputeTask",
        fromBlock: 0
    )
    input = events[events.length - 1].returnValues.callableArgs

    # decode data
    rawVotes = rlp.decode(input)
    votes = rawVotes[0]
    numVotes.set(votes.length)

    tally.set(await votingContract.methods.tally().call())


$("document").ready(
    () ->
        web3.eth.defaultAccount = (await web3.eth.getAccounts())[0]
        userAddress.set(web3.eth.defaultAccount)
        hasVoted.set(await votingContract.methods.hasVoted(web3.eth.defaultAccount).call())
        await getCurrentTally()
)


Template.body.helpers({
    tally: () -> tally.get()
    vote: () -> vote.get()
    num_votes: () -> numVotes.get()
    user_address: () -> userAddress.get()
    has_voted: () -> hasVoted.get()
})


Template.body.events({
    "click .button": (event) ->
        title = event.target.innerText
        switch title
            when "Tally votes & update tally (2 txs)"
                await tallyVotes()
            when "Vote"
                voteOption = if $("#vote_option")[0].checked then "1" else "0"
                await submitVote(voteOption)
            when "Get current tally"
                await getCurrentTally()

})