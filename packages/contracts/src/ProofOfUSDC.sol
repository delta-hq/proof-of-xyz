// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@zk-email/contracts/DKIMRegistry.sol";
import "@zk-email/contracts/utils/StringUtils.sol";
import "./utils/NFTSVG.sol";
import { Verifier } from "./Verifier.sol";

contract ProofOfUSDC is ERC721Enumerable {
    using StringUtils for *;
    using NFTSVG for *;

    uint16 public constant bytesInPackedBytes = 31;
    string constant domain = "info.coinbase.com";
    
    uint32 public constant pubKeyHashIndexInSignals = 0; 
    uint32 public constant rewardAmountIndexInSignals = 1; 
    uint32 public constant rewardAmountLengthInSignals = 1; 
    uint32 public constant headerHashIndexInSignals = 2; 
    uint32 public constant headerHashLengthInSignals = 1; 
    uint32 public constant timestampIndexInSignals = 3;
    uint32 public constant timestampLengthInSignals = 1;
    uint32 public constant addressIndexInSignals = 4; 

    uint256 private tokenCounter;
    DKIMRegistry dkimRegistry;
    Verifier public immutable verifier;

    mapping(uint256 => string) public tokenIDToRewardAmount;
    mapping(uint256 => string) public tokenIDToTimestamp;
    // is it fine to use string as key?
    mapping(string => bool) public hasMinted;

    constructor(Verifier v, DKIMRegistry d) ERC721("VerifiedEmail", "VerifiedEmail") {
        verifier = v;
        dkimRegistry = d;
    }

    function tokenDesc(uint256 tokenId) public view returns (string memory) {
        string memory reward_amount = tokenIDToRewardAmount[tokenId];  // Retrieve the username
        string memory timestamp = tokenIDToTimestamp[tokenId];    // Retrieve the timestamp
        address address_owner = ownerOf(tokenId);
        
        // Create a description with the username and timestamp
        string memory result = string(
            abi.encodePacked(
                StringUtils.toString(address_owner), 
                " earned ", 
                reward_amount, 
                " USDC at ",
                timestamp
            )
        );
        return result;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory reward_amount = tokenIDToRewardAmount[tokenId];
        address owner = ownerOf(tokenId);
        return NFTSVG.constructAndReturnSVG(reward_amount, tokenId, owner);
    }

    function _domainCheck(uint256[] memory headerSignals) public pure returns (bool) {
        string memory senderBytes = StringUtils.convertPackedBytesToString(headerSignals, 18, bytesInPackedBytes);
        string[1] memory domainStrings = ["no-reply@info.coinbase.com"];
        return StringUtils.stringEq(senderBytes, domainStrings[0]);
        // Usage: require(_domainCheck(senderBytes, domainStrings), "Invalid domain");
    }

    /// Mint a token proving USDC holdings on Coinbase by verifying proof of email
    /// @param proof ZK proof of the circuit - a[2], b[4] and c[2] encoded in series
    /// @param signals Public signals of the circuit.
    function mint(uint256[8] memory proof, uint256[5] memory signals) public {
        // TODO no invalid signal check yet, which is fine since the zk proof does it
        // Checks: Verify proof and check signals
        // require(signals[0] == 1337, "invalid signals");

        // public signals are the masked packed message bytes, and hash of public key.

        // Check eth address committed to in proof matches msg.sender, to avoid replayability
        // require(address(uint160(signals[addressIndexInSignals])) == msg.sender, "Invalid address");

        // Check from/to email domains are correct [in this case, only from domain is checked]
        // Right now, we just check that any email was received from anyone at Coinbase, which is good enough for now
        // We will upload the version with these domain checks soon!
        // require(_domainCheck(headerSignals), "Invalid domain");

        // Verify the DKIM public key hash stored on-chain matches the one used in circuit
        bytes32 dkimPublicKeyHashInCircuit = bytes32(signals[pubKeyHashIndexInSignals]);

        require(dkimRegistry.isDKIMPublicKeyHashValid(domain, dkimPublicKeyHashInCircuit), "invalid dkim signature"); 
        
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
        
        // Extract the toAddress chunks from the signals
        uint256[] memory headerHashPack = new uint256[](headerHashLengthInSignals);
        for (uint256 i = headerHashIndexInSignals; i < (headerHashIndexInSignals + headerHashLengthInSignals); i++) {
            headerHashPack[i - headerHashIndexInSignals] = signals[i];
        }

        // Convert the packed address signals into a string
        string memory headerHashString = StringUtils.convertPackedBytesToString(headerHashPack);  // Converts to string

        // Check if this hashed combination has already minted an NFT
        require(!hasMinted[headerHashString], "This address and timestamp combination has already minted an NFT.");


        // Extract the username chunks from the signals
        uint256[] memory rewardAmountPack = new uint256[](rewardAmountLengthInSignals);
        for (uint256 i = rewardAmountIndexInSignals; i < (rewardAmountIndexInSignals + rewardAmountLengthInSignals); i++) {
            rewardAmountPack[i - rewardAmountIndexInSignals] = signals[i];
        }

        // Extract the timestamp chunks from the signals
        uint256[] memory timestampPack = new uint256[](timestampLengthInSignals);
        for (uint256 i = timestampIndexInSignals; i < (timestampIndexInSignals + timestampLengthInSignals); i++) {
            timestampPack[i - timestampIndexInSignals] = signals[i];
        }

        // Effects: Mint token
        uint256 tokenId = tokenCounter + 1;

        // Convert the rewardAmount into a string using StringUtils
        string memory rewardAmountBytes = StringUtils.convertPackedBytesToString(
            rewardAmountPack,
            bytesInPackedBytes * rewardAmountLengthInSignals,
            bytesInPackedBytes
        );

        // Convert the timestamp into a string using StringUtils
        string memory timestampBytes = StringUtils.convertPackedBytesToString(
            timestampPack,
            bytesInPackedBytes * timestampLengthInSignals,
            bytesInPackedBytes
        );
        
        tokenIDToRewardAmount[tokenId] = rewardAmountBytes;
        tokenIDToTimestamp[tokenId] = timestampBytes;
        _mint(msg.sender, tokenId);
        tokenCounter = tokenCounter + 1;

        // Mark this hashed address as having minted an NFT
        hasMinted[headerHashString] = true;
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
