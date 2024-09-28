import { bytesToBigInt, fromHex } from "@zk-email/helpers/dist/binary-format";
import { generateEmailVerifierInputs } from "@zk-email/helpers/dist/input-generators";

export const REWARD_AMOUNT_PRESELECTOR = "You received ";
export const TIMESTAMP_PRESELECTOR = "t=";

export type ICoinbaseCircuitInputs = {
  emailHeader: string[];
  emailHeaderLength: string;
  pubkey: string[];
  signature: string[];
  timestampIndex: string;
  rewardAmountIndex: string;
  address: string;
  emailBody?: string[] | undefined;
  emailBodyLength?: string | undefined;
  precomputedSHA?: string[] | undefined;
  bodyHashIndex?: string | undefined;
};

export async function generateCoinbaseVerifierCircuitInputs(
  email: string | Buffer,
  ethereumAddress: string
): Promise<ICoinbaseCircuitInputs> {
  const emailVerifierInputs = await generateEmailVerifierInputs(email, {
    ignoreBodyHashCheck: true,
  });

  const headerRemaining = emailVerifierInputs.emailHeader!.map((c) => Number(c)); // Char array to Uint8Array
  
  const rewardAmountBuffer = Buffer.from(REWARD_AMOUNT_PRESELECTOR);
  const rewardAmountIndex =
    (Buffer.from(headerRemaining).indexOf(rewardAmountBuffer) + rewardAmountBuffer.length).toString();


  const timestampBuffer = Buffer.from(TIMESTAMP_PRESELECTOR);
  const timestampIndex =
    (Buffer.from(headerRemaining).indexOf(timestampBuffer) + timestampBuffer.length).toString();

  const address = bytesToBigInt(fromHex(ethereumAddress)).toString();

  return {
    ...emailVerifierInputs,
    rewardAmountIndex,
    timestampIndex,
    address,
  };
}
