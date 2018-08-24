VOTING_ADDRESS = "0xc952b2291e5d913db0a91367cb643d12802e4ff0"
vote = "1"

engUtils = require "../../enigma/enigma-utils"

Voting = artifacts.require "Voting"

clientPrivKey = "853ee410aa4e7840ca8948b8a2f67e9a1c2f4988ff5f4ec7794edf57be421ae5"
enclavePubKey = "0061d93b5412c0c99c3c7867db13c4e13e51292bd52565d002ecf845bb0cfd8adfa5459173364ea8aff3fe24054cca88581f6c3c5e928097b9d4d47fce12ae47"
derivedKey = engUtils.getDerivedKey(enclavePubKey, clientPrivKey)

module.exports = (callback) ->
    # encrypt vote
    encryptedVote = engUtils.encryptMessage(derivedKey, vote)
    console.log "Your unprefixed encrypted vote is #{encryptedVote}"

    # add prefix padding
    prefix = "0x"
    for i in [encryptedVote.length..63]
        prefix += "0"
    encryptedVote = prefix + encryptedVote
    console.log "Your encrypted vote is #{encryptedVote}"

    # audit submitted vote
    votingContract = await Voting.deployed()
    voteID = await votingContract.vote.call(encryptedVote)
    await votingContract.vote(encryptedVote)
    submittedVote = await votingContract.votes.call(voteID)
    console.log "Your submitted vote is #{submittedVote}, which is#{if submittedVote == encryptedVote then "" else "not"} equal to your original vote"