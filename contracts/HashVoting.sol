pragma solidity ^0.4.24;

import "./enigma/IEnigma.sol";
import "./Ownable.sol";

contract HashVoting is Ownable {
    address public enigmaAddress; // address of enigma contract
    bytes32[] public votes; // list of encrypted votes
    bytes32 public encodedVotesHash; // sha3 hash of current version of RLP encoded votes

    event SubmittedEncodedVotes(address _sender, uint _counterExample, bytes _newEncodedVotes);
    event TalliedVotes(int256 _tally);

    constructor (address _enigmaAddress) public {
        enigmaAddress = _enigmaAddress;
    }

    function vote(bytes32 _encryptedVote) public returns (uint _voteID) {
        // do some checks about authentication

        // add vote to votes
        votes.push(_encryptedVote);

        // return index of vote in array as voteID
        return votes.length - 1;
    }

    function submitRLPEncodedVotes(bytes _currentEncodedVotes, bytes _newEncodedVotes, uint _counterExample) public returns (bool _success) {
        // if no submissions exist, set input as encodedVotes
        if (encodedVotesHash == 0) {
            encodedVotesHash = keccak256(_newEncodedVotes);
            return true;
        }

        // there's already a submission
        // check if provided current encoded votes is legit
        if (keccak256(_currentEncodedVotes) == encodedVotesHash) {
            // check if existing submission's validity is disproven by counterExample
            if (isVoteInEncodedVotes(_currentEncodedVotes, _counterExample) == false) {
                // existing submission invalid, accept new submission
                _currentEncodedVotes = _newEncodedVotes;
                emit SubmittedEncodedVotes(msg.sender, _counterExample, _newEncodedVotes);
                return true;
            }
        }
        
        // existing submission not successfully challanged, do nothing
        return false;
    }

    function isVoteInEncodedVotes(bytes _encodedVotes, uint _voteID) public view returns (bool _isInEncodedVotes) {
        bytes32 voteInEncodedVotes; // the encrypted vote at index _voteID in encodedVotes
        bytes32 sizeOfMetaPayloadLength = _encodedVotes[0];
        bytes32 sizeOfPayloadLength;
        assembly {
            sizeOfMetaPayloadLength := div(sizeOfMetaPayloadLength, 0x100000000000000000000000000000000000000000000000000000000000000)
            sizeOfMetaPayloadLength := sub(sizeOfMetaPayloadLength, 0xf7)

            let encodedVotesPtr := add(_encodedVotes, 33) // 32 bytes encodedVotes.length + 1 byte meta prefix

            // skip metaPayloadLength
            encodedVotesPtr := add(encodedVotesPtr, sizeOfMetaPayloadLength)

            sizeOfPayloadLength := sub(mload(encodedVotesPtr), 0xf7) // mload would only load first byte of the 32 bytes loaded

            // skip payloadLength
            encodedVotesPtr := add(encodedVotesPtr, sizeOfPayloadLength)

            // jump to requested vote
            encodedVotesPtr := add(encodedVotesPtr, add(mul(_voteID, 33), 1))

            // save vote
            voteInEncodedVotes := mload(encodedVotesPtr)
        }
        return voteInEncodedVotes == votes[_voteID];
    }

    /**
        Enigma handling
     */

    // submits encrypted votes to Enigma contract
    function submitEncryptedVotes(bytes _encodedVotes) public {
        IEnigma enigma = IEnigma(enigmaAddress);
        bytes32[] memory preprocessors = new bytes32[](0);
        uint fee = 0;

        // send compute request to Enigma
        require(
            enigma.compute(
                address(this),
                "_tallyVotes(int256[])",
                _encodedVotes,
                "_callback(int256)",
                fee,
                preprocessors,
                block.number + 10
            ) == IEnigma.ReturnValue.Ok);
    }

    // broadcasts the result of the tally
    // called by Enigma contract
    function _callback(int256 _tally) public {
        require(msg.sender == enigmaAddress);
        emit TalliedVotes(_tally);
    }

    // code for tallying the votes
    // called by Enigma worker
    function _tallyVotes(int256[] _votes) public pure returns(int256 _tally) {
        assembly {
           let len := mul(mload(_votes), 32)
           let data := add(_votes, 32)

           for
               { let end := add(data, len) }
               lt(data, end)
               { data := add(data, 32) }
           {
               _tally := add(_tally, mload(data))
           }
        }
    }
}