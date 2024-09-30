pragma circom 2.1.5;

include "circomlib/circuits/poseidon.circom";
include "@zk-email/zk-regex-circom/circuits/common/to_addr_regex.circom";
include "@zk-email/zk-regex-circom/circuits/common/email_domain_regex.circom";
include "@zk-email/circuits/helpers/email-nullifier.circom";
include "@zk-email/circuits/email-verifier.circom";
include "@zk-email/circuits/utils/regex.circom";
include "./reward-amount-regex.circom";


/// @title DomainVerifier
/// @notice Circuit to verify the email domain of a user
/// @param maxHeadersLength Maximum length for the email header.
/// @param maxBodyLength Maximum length for the email body.
/// @param n Number of bits per chunk the RSA key is split into. Recommended to be 121.
/// @param k Number of chunks the RSA key is split into. Recommended to be 17.
/// @input emailHeader Email headers that are signed (ones in `DKIM-Signature` header) as ASCII int[], padded as per SHA-256 block size.
/// @input emailHeaderLength Length of the email header including the SHA-256 padding.
/// @input pubkey RSA public key split into k chunks of n bits each.
/// @input signature RSA signature split into k chunks of n bits each.
/// @input domainIndex Index of the reward amount in the email body.
/// @input address ETH address as identity commitment (to make it as part of the proof).
/// @output pubkeyHash Poseidon hash of the pubkey - Poseidon(n/2)(n/2 chunks of pubkey with k*2 bits per chunk).
template DomainVerifier(maxHeadersLength, maxBodyLength, n, k) {
    assert(n * k > 1024); // constraints for 1024 bit RSA
    
    signal input emailHeader[maxHeadersLength];
    signal input emailHeaderLength;
    signal input pubkey[k];
    signal input signature[k];
    signal input toAddrIndex;
    signal input domainIndex;
    signal input address; // we don't need to constrain the + 1 due to https://geometry.xyz/notebook/groth16-malleability

    signal output pubkeyHash;
    signal output domain;

    // TODO: implement this
    signal output toAddrHash;

    component EV = EmailVerifier(maxHeadersLength, maxBodyLength, n, k, 1);
    EV.emailHeader <== emailHeader;
    EV.pubkey <== pubkey;
    EV.signature <== signature;
    EV.emailHeaderLength <== emailHeaderLength;
    pubkeyHash <== EV.pubkeyHash;

    // TO ADDR REGEX
    signal (toAddrFound, toAddrReveal[maxHeadersLength]) <== ToAddrRegex(maxHeadersLength)(emailHeader);
    toAddrFound === 1;

    signal isToAddrIndexValid <== LessThan(log2Ceil(maxHeadersLength))([toAddrIndex, emailHeaderLength]);
    isToAddrIndexValid === 1;

    var maxToAddrLength = 255;
    signal toAddrPacks[9] <== PackRegexReveal(maxHeadersLength, maxToAddrLength)(toAddrReveal, toAddrIndex); 
    toAddrHash <== Poseidon(9)(toAddrPacks);

    // DOMAIN REGEX
    signal (domainFound, domainReveal[maxHeadersLength]) <== EmailDomainRegex(maxHeadersLength)(emailHeader);
    domainFound === 1;

    signal isDomainIndexValid <== LessThan(log2Ceil(maxHeadersLength))([domainIndex, emailHeaderLength]);
    isDomainIndexValid === 1;

    var maxDomainLength = 255;
    signal domainPacks[9] <== PackRegexReveal(maxHeadersLength, maxDomainLength)(domainReveal, domainIndex);   
    
    domain <== domainPacks[0];
    
}


component main { public [ address ] } = DomainVerifier(1024, 0, 121, 17);