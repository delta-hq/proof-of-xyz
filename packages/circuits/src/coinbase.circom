pragma circom 2.1.5;

include "@zk-email/zk-regex-circom/circuits/common/from_addr_regex.circom";
include "@zk-email/zk-regex-circom/circuits/common/to_addr_regex.circom";
include "@zk-email/zk-regex-circom/circuits/common/timestamp_regex.circom";
include "@zk-email/circuits/helpers/email-nullifier.circom";
include "@zk-email/circuits/email-verifier.circom";
include "@zk-email/circuits/utils/regex.circom";
include "./reward-amount-regex.circom";


/// @title CoinbaseVerifier
/// @notice Circuit to verify input email matches Coinbase USDC reward, and extract the reward amount
/// @param maxHeadersLength Maximum length for the email header.
/// @param maxBodyLength Maximum length for the email body.
/// @param n Number of bits per chunk the RSA key is split into. Recommended to be 121.
/// @param k Number of chunks the RSA key is split into. Recommended to be 17.
/// @input emailHeader Email headers that are signed (ones in `DKIM-Signature` header) as ASCII int[], padded as per SHA-256 block size.
/// @input emailHeaderLength Length of the email header including the SHA-256 padding.
/// @input pubkey RSA public key split into k chunks of n bits each.
/// @input signature RSA signature split into k chunks of n bits each.
/// @input rewardAmountIndex Index of the reward amount in the email body.
/// @input address ETH address as identity commitment (to make it as part of the proof).
/// @output pubkeyHash Poseidon hash of the pubkey - Poseidon(n/2)(n/2 chunks of pubkey with k*2 bits per chunk).
template CoinbaseVerifier(maxHeadersLength, maxBodyLength, n, k) {
    assert(n * k > 1024); // constraints for 1024 bit RSA
    
    signal input emailHeader[maxHeadersLength];
    signal input emailHeaderLength;
    signal input pubkey[k];
    signal input signature[k];
    signal input timestampIndex;
    signal input rewardAmountIndex;
    signal input address; // we don't need to constrain the + 1 due to https://geometry.xyz/notebook/groth16-malleability

    signal output pubkeyHash;
    signal output rewardAmount;

    // switch to use EmailNullifier (signature)
    signal output emailHeaderHash;
    signal output timestamp;    

    component EV = EmailVerifier(maxHeadersLength, maxBodyLength, n, k, 1);
    EV.emailHeader <== emailHeader;
    EV.pubkey <== pubkey;
    EV.signature <== signature;
    EV.emailHeaderLength <== emailHeaderLength;
    pubkeyHash <== EV.pubkeyHash;

    emailHeaderHash <== EmailNullifier(n, k)(signature);

    // TIMESTAMP REGEX

    signal (timeStampFound, timestampReveal[maxHeadersLength]) <== TimestampRegex(maxHeadersLength)(emailHeader);
    timeStampFound === 1;

    signal istimestampIndexValid <== LessThan(log2Ceil(maxHeadersLength))([timestampIndex, emailHeaderLength]);
    istimestampIndexValid === 1;

    var maxTimestampLength = 10;
    signal timestampPacks[1] <== PackRegexReveal(maxHeadersLength, maxTimestampLength)(timestampReveal, timestampIndex);   
    
    timestamp <== timestampPacks[0];

    // REWARD AMOUNT REGEX
    // This computes the regex states on each character in the email body. For other apps, this is the
    // section that you want to swap out via using the zk-regex library.
    signal (rewardAmountFound, rewardAmountReveal[maxHeadersLength]) <== RewardAmountRegex(maxHeadersLength)(emailHeader);
    rewardAmountFound === 1;

    // Assert rewardAmountIndex < emailHeaderLength
    signal isRewardAmountIndexValid <== LessThan(log2Ceil(maxHeadersLength))([rewardAmountIndex, emailHeaderLength]);
    isRewardAmountIndexValid === 1;

    // Pack the reward amount to int
    var maxRewardAmountLength = 8;
    signal rewardAmountPacks[1] <== PackRegexReveal(maxHeadersLength, maxRewardAmountLength)(rewardAmountReveal, rewardAmountIndex);
   
    // Reward amount will fit in one field element, so we take the first item from the packed array.
    rewardAmount <== rewardAmountPacks[0];
}


component main { public [ address ] } = CoinbaseVerifier(1024, 0, 121, 17);