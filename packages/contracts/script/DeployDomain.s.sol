pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "../src/DomainVerifier.sol";
import "../src/ProofOfDomain.sol";

contract Deploy is Script, Test {
    function getPrivateKey() internal view returns (uint256) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        if (privateKey == 0) {
            revert("PRIVATE_KEY is not set");
        }
        return privateKey;
    }

    function run() public {
        uint256 sk = getPrivateKey();
        address owner = vm.createWallet(sk).addr;
        vm.startBroadcast(sk);

        DomainVerifier proofVerifier = new DomainVerifier();
        console.log("Deployed Verifier at address: %s", address(proofVerifier));

        DKIMRegistry dkimRegistry = new DKIMRegistry(owner);
        console.log("Deployed DKIMRegistry at address: %s", address(dkimRegistry));

        dkimRegistry.setDKIMPublicKeyHash(
            "accounts.google.com",
            bytes32(uint256(3024598485745563149860456768272954250618223591034926533254923041921841324429))
        );

        ProofOfDomain testVerifier = new ProofOfDomain(proofVerifier, dkimRegistry);
        console.log("Deployed ProofOfDomain at address: %s", address(testVerifier));

        vm.stopBroadcast();
    }
}
