pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "../src/ProofOfUSDC.sol";
import "../src/Verifier.sol";

contract Deploy is Script, Test {
    function getPrivateKey() internal returns (uint256) {
        try vm.envUint("PRIVATE_KEY") returns (uint256 privateKey) {
            return privateKey;
        } catch {
            // This is the anvil default exposed secret key
            return 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
    }

    function run() public {
        uint256 sk = getPrivateKey();
        address owner = vm.createWallet(sk).addr;
        vm.startBroadcast(sk);

        Verifier proofVerifier = new Verifier();
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
