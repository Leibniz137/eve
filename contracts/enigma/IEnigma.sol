pragma solidity ^0.4.24;

contract IEnigma {
    enum ReturnValue {Ok, Error}

    function compute(
        address dappContract,
        string callable,
        bytes callableArgs,
        string callback,
        uint256 fee,
        bytes32[] preprocessors,
        uint256 blockNumber
    )
        public
        returns (ReturnValue);
}