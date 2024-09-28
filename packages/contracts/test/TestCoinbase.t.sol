pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "../src/ProofOfUSDC.sol";
import "../src/Verifier.sol";

contract CoinbaseUtilsTest is Test {
    using StringUtils for *;

    address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D; // Hardcoded address of the VM from foundry

    Verifier proofVerifier;
    DKIMRegistry dkimRegistry;
    ProofOfUSDC testVerifier;

    uint16 public constant packSize = 7;

    function setUp() public {
         console.log("running set up");
        address owner = vm.addr(1);

        vm.startPrank(owner);

        proofVerifier = new Verifier();
        dkimRegistry = new DKIMRegistry(owner);

        // These are the Poseidon hash of DKIM public keys for info.coinbase.com
        // This was calcualted using https://github.com/zkemail/zk-email-verify/tree/main/packages/scripts
        dkimRegistry.setDKIMPublicKeyHash(
            "info.coinbase.com",
            0x05289f31a838d16aa64b8bd0519d7de1add46548299208c6cf81914c2bf2ee8b
        );

        testVerifier = new ProofOfUSDC(proofVerifier, dkimRegistry);

        vm.stopPrank();
    }

    // These proof and public input values are generated using scripts in packages/circuits/scripts/generate-proof.ts
    // The sample email in `/emls` is used as the input, but you will have different values if you generated your own zkeys
    function testVerifyTestEmail() public {
        uint256[5] memory publicSignals;
        publicSignals[
            0
        ] = 2333336841929832288695187135562794652748341581135245042999961983084532002443;
        publicSignals[1] = 909258290;
        publicSignals[2] = 21583661305191324841426121921777127372562589899224514570760757141952266060127;
        publicSignals[3] = 237100123279274017961777;
        publicSignals[4] = 333204821482021981323833993247527139185603938597;

        uint256[2] memory proof_a = [
            1014776802798613093926375218064625969383807316192874448051133110845798885818,
            12131462535924484025855968336477409947731009545366864287146739542704210320720
        ];
        // Note: you need to swap the order of the two elements in each subarray
        uint256[2][2] memory proof_b = [
            [
                1093065977845156168097554692083960665350343390642801264884994843166034238,
                7200492887950045008795564870127176357379492661837713868624559236298477932983
            ],
            [
                4458329650975235986732018075514771017351367700074618120869443039223992446557,
                20411626305249066739559848144497020606071612129443018166545307584053170188991
            ]
        ];
        uint256[2] memory proof_c = [
            817668341908270338591455608917218410155743724545461812031930158479828568285,
            8025314823908604650107495339825380284647114275083617400693916891755068224252
        ];

        uint256[8] memory proof = [
            proof_a[0],
            proof_a[1],
            proof_b[0][0],
            proof_b[0][1],
            proof_b[1][0],
            proof_b[1][1],
            proof_c[0],
            proof_c[1]
        ];

        // Test proof verification
        bool verified = proofVerifier.verifyProof(
            proof_a,
            proof_b,
            proof_c,
            publicSignals
        );
        assertEq(verified, true);

        // Test mint after spoofing msg.sender
        Vm vm = Vm(VM_ADDR);
        vm.startPrank(0x0000000000000000000000000000000000000001);
        testVerifier.mint(proof, publicSignals);
        vm.stopPrank();
    }

    function testSVG() public {
        testVerifyTestEmail();
        string memory svgValue = testVerifier.tokenURI(1);
        console.log(svgValue);
        assert(bytes(svgValue).length > 0);
    }

    function testChainID() public view {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        console.log(chainId);
        // Local chain, xdai, goerli, mainnet
        assert(
            chainId == 31337 || chainId == 100 || chainId == 5 || chainId == 1
        );
    }
}
