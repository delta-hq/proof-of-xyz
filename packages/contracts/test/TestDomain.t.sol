pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "../src/ProofOfDomain.sol";
import "../src/DomainVerifier.sol";

contract DomainUtilsTest is Test {
    using StringUtils for *;

    address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D; // Hardcoded address of the VM from foundry

    DomainVerifier proofVerifier;
    DKIMRegistry dkimRegistry;
    ProofOfDomain testVerifier;

    uint16 public constant packSize = 7;

    function setUp() public {
         console.log("running set up");
        address owner = vm.addr(1);

        vm.startPrank(owner);

        proofVerifier = new DomainVerifier();
        dkimRegistry = new DKIMRegistry(owner);

        // These are the Poseidon hash of DKIM public keys for 
        dkimRegistry.setDKIMPublicKeyHash(
            "google.com",
            0x226D374830985893D9592DA9AA8D10DA21F2EA26712A692E99AB3F8DE95E6EBA
        );

        testVerifier = new ProofOfDomain(proofVerifier, dkimRegistry);

        vm.stopPrank();
    }

    // These proof and public input values are generated using scripts in packages/circuits/scripts/generate-proof.ts
    // The sample email in `/emls` is used as the input, but you will have different values if you generated your own zkeys
    function testVerifyTestEmail() public {
        uint256[2] memory publicSignals;
        publicSignals[
            0
        ] = 3024598485745563149860456768272954250618223591034926533254923041921841324429;
        publicSignals[1] = 531326660592781811838081523851630366386682486042;

        uint256[2] memory proof_a = [
            8784964908323934696780038963224291828068273234126218872665027929242431267463,
            19107210326381036071319659629722057000259148878209103118167510305341695012731
        ];
        // Note: you need to swap the order of the two elements in each subarray
        uint256[2][2] memory proof_b = [
            [
                17950129405847321032081698097799857623465684923607767428215431085286280229837,
                13617508604659176950175420129743592608465406113137924670181860578473018075673
            ],
            [
                4975039244320864270317054672490356703862913528956158275688102841839898781072,
                14837690292322171498448457350785532442431656302370784617175259230931337325491
            ]
        ];
        uint256[2] memory proof_c = [
            11983350954552349157946289294613751083477787676023604124012599721285253700518,
            12939783046782502005879974004277780521244786514872255091287824403021636538541
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
