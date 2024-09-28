import { buildPoseidon } from "circomlibjs";
import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateCoinbaseVerifierCircuitInputs } from "../helpers";
import { bigIntToChunkedBytes, bytesToBigInt, packedNBytesToString } from "@zk-email/helpers/dist/binary-format";

const path = require("path");
const fs = require("fs");
const wasm_tester = require("circom_tester").wasm;


describe("Coinbase email test", function () {
  jest.setTimeout(10 * 60 * 1000); // 10 minutes

  let rawEmail: Buffer;
  let circuit: any;
  const ethAddress = "0x3A5d6bc34c12f1C95AB6Ffe266629751c6388925";

  beforeAll(async () => {
    rawEmail = fs.readFileSync(
      path.join(__dirname, "./emls/coinbase-test.eml"),
      "utf8"
    );

    // const dkimResult = await verifyDKIMSignature(rawEmail, "info.coinbase.com");
    // console.log("DKIM Selector", dkimResult.selector.toString());
    // console.log("DKIM PK", dkimResult.publicKey.toString());
    // const poseidon = await buildPoseidon();
    // const pubkeyChunked = bigIntToChunkedBytes(dkimResult.publicKey, 242, 9);
    // const hash = poseidon(pubkeyChunked);
    // console.log("hash", hash.toString());
    // process.exit(0);

    circuit = await wasm_tester(path.join(__dirname, "../src/coinbase.circom"), {
      // NOTE: We are running tests against pre-compiled circuit in the below path
      // You need to manually compile when changes are made to circuit if `recompile` is set to `false`.
      recompile: true,
      output: path.join(__dirname, "../build/coinbase"),
      include: [path.join(__dirname, "../node_modules"), path.join(__dirname, "../../../node_modules")],
    });
  });

  it("should verify coinbase email", async function () {
    const coinbaseVerifierInputs = await generateCoinbaseVerifierCircuitInputs(rawEmail, ethAddress);
    const witness = await circuit.calculateWitness(coinbaseVerifierInputs);
    await circuit.checkConstraints(witness);
    // Calculate DKIM pubkey hash to verify its same as the one from circuit output
    // We input pubkey as 121 * 17 chunk, but the circuit convert it to 242 * 9 chunk for hashing
    // https://zkrepl.dev/?gist=43ce7dce2466c63812f6efec5b13aa73 - This can be used to get pubkey hash from 121 * 17 chunk
    const dkimResult = await verifyDKIMSignature(rawEmail, "info.coinbase.com");
    const poseidon = await buildPoseidon();
    const pubkeyChunked = bigIntToChunkedBytes(dkimResult.publicKey, 242, 9);
    const hash = poseidon(pubkeyChunked);

    // Assert pubkey hash
    expect(witness[1]).toEqual(poseidon.F.toObject(hash));

    // Verify the username is correctly extracted and packed form email body
    const rewardAmountBytes = new TextEncoder().encode("2.26").reverse(); // Circuit pack in reverse order
    expect(witness[2]).toEqual(bytesToBigInt(rewardAmountBytes));

    // todo: insert header hash check here

    const timestampBytes = new TextEncoder().encode("1725583952").reverse(); // Circuit pack in reverse order
    expect(witness[4]).toEqual(bytesToBigInt(timestampBytes));

    // Check address public input
    expect(witness[5]).toEqual(BigInt(ethAddress));
  });

  it("should fail if the rewardAmountIndex is invalid", async function () {
    const coinbaseVerifierInputs = await generateCoinbaseVerifierCircuitInputs(rawEmail, ethAddress);
    coinbaseVerifierInputs.rewardAmountIndex = (Number((await coinbaseVerifierInputs).rewardAmountIndex) + 1).toString();

    expect.assertions(1);

    try {
      const witness = await circuit.calculateWitness(coinbaseVerifierInputs);
      await circuit.checkConstraints(witness);
    } catch (error) {
      expect((error as Error).message).toMatch("Assert Failed");
    }
  })

  it("should fail if the rewardAmountIndex is out of bounds", async function () {
    const coinbaseVerifierInputs = await generateCoinbaseVerifierCircuitInputs(rawEmail, ethAddress);
    coinbaseVerifierInputs.rewardAmountIndex = (coinbaseVerifierInputs.emailHeaderLength! + 1).toString();

    expect.assertions(1);

    try {
      const witness = await circuit.calculateWitness(coinbaseVerifierInputs);
      await circuit.checkConstraints(witness);
    } catch (error) {
      expect((error as Error).message).toMatch("Assert Failed");
    }
  })
});
