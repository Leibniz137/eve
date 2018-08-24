var Voting = artifacts.require("Voting");
var Enigma = artifacts.require("Enigma");

module.exports = async function(deployer, network, accounts) {
    deployer.then(async () => {
        enigma = await deployer.deploy(Enigma, "0x0", accounts[0])
        await deployer.deploy(Voting, enigma.address);
    })
};