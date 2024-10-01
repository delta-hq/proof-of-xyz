// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "@zk-email/contracts/utils/StringUtils.sol";
import "./utils/NFTSVG.sol";
import { DomainVerifier } from "./DomainVerifier.sol";

contract ProofOfDomain is ERC721Enumerable {
    using StringUtils for *;
    using NFTSVG for *;

    uint16 public constant bytesInPackedBytes = 31;
    string constant senderDomain = "google.com";
    
    uint32 public constant pubKeyHashIndexInSignals = 0; 
    uint32 public constant toAddrHashIndexInSignals = 1; 
    uint32 public constant toAddrHashLengthInSignals = 1; 
    uint32 public constant domainIndexInSignals = 2;
    uint32 public constant domainLengthInSignals = 1;
    uint32 public constant addressIndexInSignals = 3; 

    uint256 private tokenCounter;
    DKIMRegistry dkimRegistry;
    DomainVerifier public immutable verifier;

    mapping(uint256 => string) public tokenIDToToAddrHash;
    mapping(uint256 => string) public tokenIDToDomain;
    // is it fine to use string as key?
    mapping(string => bool) public hasMinted;

    constructor(DomainVerifier v, DKIMRegistry d) ERC721("VerifiedEmail", "VerifiedEmail") {
        verifier = v;
        dkimRegistry = d;
    }

    function tokenDesc(uint256 tokenId) public view returns (string memory) {
        string memory domain = tokenIDToDomain[tokenId];    // Retrieve the domain
        address address_owner = ownerOf(tokenId);
        
        // Create a description with the username and domain
        string memory result = string(
            abi.encodePacked(
                StringUtils.toString(address_owner), 
                " is affiliated to ", 
                domain
            )
        );
        return result;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory domain = tokenIDToDomain[tokenId];
        address owner = ownerOf(tokenId);
        return NFTSVG.constructAndReturnSVG(domain, tokenId, owner);
    }

    /// Mint a token proving ownership of an email domain by verifying proof of email
    /// @param proof ZK proof of the circuit - a[2], b[4] and c[2] encoded in series
    /// @param signals Public signals of the circuit.
    function mint(uint256[8] memory proof, uint256[4] memory signals) public {
        // Verify the DKIM public key hash stored on-chain matches the one used in circuit
        bytes32 dkimPublicKeyHashInCircuit = bytes32(signals[pubKeyHashIndexInSignals]);

        require(dkimRegistry.isDKIMPublicKeyHashValid(senderDomain, dkimPublicKeyHashInCircuit), "invalid dkim signature"); 
        
        // Verify RSA and proof
        require(
            verifier.verifyProof(
                [proof[0], proof[1]],
                [[proof[2], proof[3]], [proof[4], proof[5]]],
                [proof[6], proof[7]],
                signals
            ),
            "Invalid Proof"
        );
        
        // Extract the to address chunks from the signals
        uint256[] memory toAddrHashPack = new uint256[](toAddrHashLengthInSignals);
        for (uint256 i = toAddrHashIndexInSignals; i < (toAddrHashIndexInSignals + toAddrHashLengthInSignals); i++) {
            toAddrHashPack[i - toAddrHashIndexInSignals] = signals[i];
        }

        // Convert the packed address signals into a string
        string memory toAddrHashString = StringUtils.convertPackedBytesToString(toAddrHashPack);  // Converts to string

        // Check if this to address has already minted an NFT
        require(!hasMinted[toAddrHashString], "This to address has already minted an NFT.");

        // Extract the domain chunks from the signals
        uint256[] memory domainPack = new uint256[](domainLengthInSignals);
        for (uint256 i = domainIndexInSignals; i < (domainIndexInSignals + domainLengthInSignals); i++) {
            domainPack[i - domainIndexInSignals] = signals[i];
        }

        // Effects: Mint token
        uint256 tokenId = tokenCounter + 1;

        // Convert the domain into a string using StringUtils
        string memory domainBytes = StringUtils.convertPackedBytesToString(
            domainPack,
            bytesInPackedBytes * domainLengthInSignals,
            bytesInPackedBytes
        );
        
        tokenIDToDomain[tokenId] = domainBytes;
        _mint(msg.sender, tokenId);
        tokenCounter = tokenCounter + 1;

        // Mark this hashed email as having minted an NFT
        hasMinted[toAddrHashString] = true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(
            from == address(0),
            "Cannot transfer - VerifiedEmail is soulbound"
        );
    }
}
