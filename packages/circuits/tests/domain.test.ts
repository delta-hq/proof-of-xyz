import { buildPoseidon } from "circomlibjs";
import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateDomainVerifierCircuitInputs } from "../helpers";
import {
  bigIntToChunkedBytes,
  bytesToBigInt,
  packedNBytesToString,
} from "@zk-email/helpers/dist/binary-format";
import { getPublicKeyForDomainAndSelector } from "../helpers";
const path = require("path");
const fs = require("fs");
const wasm_tester = require("circom_tester").wasm;

describe("Domain email test", function () {
  jest.setTimeout(10 * 60 * 1000); // 10 minutes

  let rawEmail: Buffer;
  let circuit: any;
  const ethAddress = "0x3A5d6bc34c12f1C95AB6Ffe266629751c6388925";

  beforeAll(async () => {
    rawEmail = fs.readFileSync(
      path.join(__dirname, "./emls/domain-test.eml"),
      "utf8"
    );

    circuit = await wasm_tester(path.join(__dirname, "../src/domain.circom"), {
      // NOTE: We are running tests against pre-compiled circuit in the below path
      // You need to manually compile when changes are made to circuit if `recompile` is set to `false`.
      recompile: false,
      output: path.join(__dirname, "../build/domain"),
      include: [
        path.join(__dirname, "../node_modules"),
        path.join(__dirname, "../../../node_modules"),
      ],
    });
  });

  it("should verify email", async function () {
    const domainVerifierInputs = await generateDomainVerifierCircuitInputs(
      rawEmail,
      ethAddress
    );

    const witness = await circuit.calculateWitness(domainVerifierInputs);
    await circuit.checkConstraints(witness);
    // Calculate DKIM pubkey hash to verify its same as the one from circuit output
    // We input pubkey as 121 * 17 chunk, but the circuit convert it to 242 * 9 chunk for hashing
    // https://zkrepl.dev/?gist=43ce7dce2466c63812f6efec5b13aa73 - This can be used to get pubkey hash from 121 * 17 chunk

    const dkimResult = await verifyDKIMSignature(
      rawEmail,
      "accounts.google.com"
    );
    const poseidon = await buildPoseidon();
    const pubkeyChunked = bigIntToChunkedBytes(dkimResult.publicKey, 242, 9);

    const hash = poseidon(pubkeyChunked);

    // Assert pubkey hash
    expect(witness[1]).toEqual(poseidon.F.toObject(hash));

    // todo: insert to address hash check here

    const domainBytes = new TextEncoder().encode("openblocklabs.com").reverse(); // Circuit pack in reverse order
    expect(witness[3]).toEqual(bytesToBigInt(domainBytes));

    // Check address public input
    expect(witness[12]).toEqual(BigInt(ethAddress));
  });

  it("should fail if the rewardAmountIndex is invalid", async function () {
    const domainVerifierInputs = await generateDomainVerifierCircuitInputs(
      rawEmail,
      ethAddress
    );
    domainVerifierInputs.domainIndex = (
      Number((await domainVerifierInputs).domainIndex) + 1
    ).toString();

    expect.assertions(1);

    try {
      const witness = await circuit.calculateWitness(domainVerifierInputs);
      await circuit.checkConstraints(witness);
    } catch (error) {
      expect((error as Error).message).toMatch("Assert Failed");
    }
  });

  it("should fail if the rewardAmountIndex is out of bounds", async function () {
    const domainVerifierInputs = await generateDomainVerifierCircuitInputs(
      rawEmail,
      ethAddress
    );
    domainVerifierInputs.domainIndex = (
      domainVerifierInputs.domainIndex! + 1
    ).toString();

    expect.assertions(1);

    try {
      const witness = await circuit.calculateWitness(domainVerifierInputs);
      await circuit.checkConstraints(witness);
    } catch (error) {
      expect((error as Error).message).toMatch("Assert Failed");
    }
  });
});
