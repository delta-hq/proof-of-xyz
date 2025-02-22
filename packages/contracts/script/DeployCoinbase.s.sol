pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "../src/ProofOfUSDC.sol";
import "../src/CoinbaseVerifier.sol";

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

        CoinbaseVerifier proofVerifier = new CoinbaseVerifier();
        console.log("Deployed Verifier at address: %s", address(proofVerifier));

        DKIMRegistry dkimRegistry = new DKIMRegistry(owner);
        console.log("Deployed DKIMRegistry at address: %s", address(dkimRegistry));

        // info.coinbase.com hash for selector utmvq47cidwb6eo5dijoyabype4gxcbw
        dkimRegistry.setDKIMPublicKeyHash(
            "info.coinbase.com",
            0x05289f31a838d16aa64b8bd0519d7de1add46548299208c6cf81914c2bf2ee8b
        );

        ProofOfUSDC testVerifier = new ProofOfUSDC(proofVerifier, dkimRegistry);
        console.log("Deployed ProofOfUSDC at address: %s", address(testVerifier));

        vm.stopBroadcast();
    }
}
