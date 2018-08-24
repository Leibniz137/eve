pragma solidity ^0.4.24;

import "./enigma/IEnigma.sol";
import "./Ownable.sol";

contract BatchVoting is Ownable {
    uint256 private constant ONE = 1;
    uint256 public constant BATCH_SIZE = 1000; // size of each batch of votes to be tallied

    address public enigmaAddress; // address of enigma contract
    bytes32[BATCH_SIZE][] public votes; // list batches of encrypted votes
    uint256 public currentID;

    mapping(uint256 => bool) public batchTallied;
    int256 public tally;

    event TalliedVotes(uint256 _batchID, int256 _tally);

    constructor (address _enigmaAddress) public {
        enigmaAddress = _enigmaAddress;
        votes.length = 1;
    }

    function vote(bytes32 _encryptedVote) public returns (uint256 _voteID) {
        // do some checks about authentication

        // add vote to votes
        votes[votes.length - 1][currentID] = _encryptedVote;
        _voteID = BATCH_SIZE * (votes.length - 1) + currentID;

        // update pointer to next empty slot
        currentID = addmod(currentID, 1, BATCH_SIZE);
        if (currentID == 0) {
            votes.length += 1;
        }
    }

    function getVote(uint256 _voteID) public view returns (bytes32) {
        uint256 batchID = _voteID / BATCH_SIZE;
        uint256 voteID = _voteID % BATCH_SIZE;
        return votes[batchID][voteID];
    }

    /**
        Enigma handling
     */

    // submits encrypted votes to Enigma contract
    function tallyVotesForBatch(uint256 _batchID) public {
        require(_batchID < votes.length);
        require(!batchTallied[_batchID]);
        batchTallied[_batchID] = true;

        IEnigma enigma = IEnigma(enigmaAddress);
        bytes32[] memory preprocessors = new bytes32[](0);
        uint fee = 0;

        // send compute request to Enigma
        enigma.compute(
            address(this),
            "_tallyVotes(uint256,int256[1000])",
            rlpEncode(_batchID, votes[_batchID]),
            "_callback(uint256,int256)",
            fee,
            preprocessors,
            123);
    }

    // broadcasts the result of the tally
    // called by Enigma contract
    function _callback(uint256 _batchID, int256 _tally) public {
        require(msg.sender == enigmaAddress);
        emit TalliedVotes(_batchID, _tally);
        tally += _tally;
    }

    // code for tallying the votes
    // called by Enigma worker
    function _tallyVotes(uint256 _batchID, int256[BATCH_SIZE] _votes) public pure returns(uint256 __batchID, int256 _tally) {
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
        __batchID = _batchID;
    }

    /**
        Library
     */

    // Encodes input args using RLP encoding
    // Format: [ uint256, bytes32[] ]
    function rlpEncode(uint256 _batchID, bytes32[BATCH_SIZE] _data) public pure returns (bytes) {
        // payload refers to the un-prefixed bytes32[] RLP encoded data
        require(_data.length * 33 < 2 ** 64 - 1);
        uint64 payloadLen = uint64(_data.length * 33); // plus 1 prefix byte for each item
        uint8 payloadLenNumBytes;
        bytes8 payloadLenBytes8;
        (payloadLenNumBytes, payloadLenBytes8) = toMinBytes(payloadLen);

        // metaPayload refers to the un-prefixed outer array's RLP encoded data
        require(payloadLen + 1 + payloadLenNumBytes + 33 < 2 ** 64 - 1);
        uint64 metaPayloadLen = payloadLen + 1 + payloadLenNumBytes + 33; // 33 is for the batchID
        uint8 metaPayloadLenNumBytes;
        bytes8 metaPayloadLenBytes8;
        (metaPayloadLenNumBytes, metaPayloadLenBytes8) = toMinBytes(metaPayloadLen);
        
        bytes memory result = new bytes(metaPayloadLen + 1 + metaPayloadLenNumBytes); // plus 1 prefix byte and length bytes
        assembly {
            let resultPtr := add(result, 32) // first 32 bytes is length
            let dataPtr := add(_data, 32)
            
            // store outer array's prefix byte 0xf7 + metaPayloadLenNumBytes
            mstore8(resultPtr, add(0xf7, metaPayloadLenNumBytes))
            resultPtr := add(resultPtr, 1)

            // store metaPayload length in fewest bits
            mstore(resultPtr, metaPayloadLenBytes8)
            resultPtr := add(resultPtr, metaPayloadLenNumBytes)

            // store batchID prefix byte 0x80 + 0x20 = 0xa0
            mstore8(resultPtr, 0xa0)
            resultPtr := add(resultPtr, 1)

            // store batchID
            mstore(resultPtr, _batchID)
            resultPtr := add(resultPtr, 32)

            // store bytes32[] prefix byte 0xf7 + payloadLenNumBytes
            mstore8(resultPtr, add(0xf7, payloadLenNumBytes))
            resultPtr := add(resultPtr, 1)

            // store payload length in fewest bits
            mstore(resultPtr, payloadLenBytes8)
            resultPtr := add(resultPtr, payloadLenNumBytes)

            // store items
            let prefix := 0xa0 // 0x80 + 0x20(32)
            for
                { let end := add(resultPtr, payloadLen) }
                lt(resultPtr, end)
                { 
                    resultPtr := add(resultPtr, 32)
                    dataPtr := add(dataPtr, 32)
                }
            {
                mstore8(resultPtr, prefix)
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, mload(dataPtr))
            }
        }
        return result;
    }

    /**
        Compute the largest integer smaller than or equal to the binary logarithm of the input.
        Source: https://github.com/bancorprotocol/contracts/blob/master/solidity/contracts/converter/BancorFormula.sol
    */
    function floorLog2(uint256 _n) internal pure returns (uint8) {
        uint8 res = 0;

        if (_n < 256) {
            // At most 8 iterations
            while (_n > 1) {
                _n >>= 1;
                res += 1;
            }
        }
        else {
            // Exactly 8 iterations
            for (uint8 s = 128; s > 0; s >>= 1) {
                if (_n >= (ONE << s)) {
                    _n >>= s;
                    res |= s;
                }
            }
        }

        return res;
    }

    // Converts a 64-bit uint to bytes8 and calculates how many bytes it takes up
    // returns (numBytes, nInBytes8)
    function toMinBytes(uint64 _n) internal pure returns (uint8, bytes8) {
        uint8 log2N = floorLog2(_n);
        // numBytes = ceil(floorLog2(_n) + 1 / 8)
        uint8 numBytes = (log2N + 1) / 8;
        numBytes += (log2N + 1) % 8 == 0 ? 0 : 1;
        bytes8 nInBytes8 = bytes8(_n) << (8 * (8 - numBytes));
        return (numBytes, nInBytes8);
    }
}