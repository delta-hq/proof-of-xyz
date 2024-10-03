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
            "accounts.google.com",
            bytes32(uint256(3024598485745563149860456768272954250618223591034926533254923041921841324429))
        );

        testVerifier = new ProofOfDomain(proofVerifier, dkimRegistry);

        vm.stopPrank();
    }

    // These proof and public input values are generated using scripts in packages/circuits/scripts/generate-proof.ts
    // The sample email in `/emls` is used as the input, but you will have different values if you generated your own zkeys
    function testVerifyTestEmail() public {
        uint256[12] memory publicSignals;
        publicSignals[
            0
        ] = 3024598485745563149860456768272954250618223591034926533254923041921841324429;
        publicSignals[1] = 17828471656969874523761533659198256094298520842093394689083072489124511153298;
        publicSignals[2] = 37238837281435940893216158903997324161135;
        publicSignals[3] = 2950364651888218655806831163309609337827127031971631815531098823196672;
        publicSignals[4] = 0;
        publicSignals[5] = 196879216288547622600363845727314428056620334540132446872566166008098717696;
        publicSignals[6] = 40944534594581064809821079932100186685829508258752884;
        publicSignals[7] = 0;
        publicSignals[8] = 0;
        publicSignals[9] = 0;
        publicSignals[10] = 0;
        publicSignals[11] = 531326660592781811838081523851630366386682486042;

        uint256[2] memory proof_a = [
            1550078503789914513640657840287478232215731817805425536647120407601891786433,
            10259231794004341930321094073245077504146376892636684914580999562070971535011
        ];
        // Note: you need to swap the order of the two elements in each subarray
        uint256[2][2] memory proof_b = [
            [
                4609350113592385067209260978113211325602931036421371311223176729778749620507,
                12540169096160340852651665560147412084692435715325859677212960142250973968576
            ],
            [
                18628699828616890611513573013208790212510899446742543240451706310915498169196,
                13805743370016949205872144984676237121941845894586505976965695293043453079513
            ]
        ];
        uint256[2] memory proof_c = [
            9826335705090732346894661662321262069418393441229965450586347946917682084100,
            12595964521863172630340225308859371854932487360297401692484569606138082400678
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
