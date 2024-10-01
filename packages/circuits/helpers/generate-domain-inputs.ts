import { bytesToBigInt, fromHex } from "@zk-email/helpers/dist/binary-format";
import { generateEmailVerifierInputs } from "@zk-email/helpers/dist/input-generators";

export const TO_PRESELECTOR = "To: ";

export type IDomainCircuitInputs = {
  emailHeader: string[];
  emailHeaderLength: string;
  pubkey: string[];
  signature: string[];
  toAddrIndex: string | undefined;
  domainIndex: string | undefined;
  address: string;
  emailBody?: string[] | undefined;
  emailBodyLength?: string | undefined;
  precomputedSHA?: string[] | undefined;
  bodyHashIndex?: string | undefined;
};

export async function generateDomainVerifierCircuitInputs(
  email: string | Buffer,
  ethereumAddress: string
): Promise<IDomainCircuitInputs> {
  const emailVerifierInputs = await generateEmailVerifierInputs(email, {
    ignoreBodyHashCheck: true,
  });

const headerRemaining = emailVerifierInputs.emailHeader!.map((c) => Number(c)); // Char array to Uint8Array

 // Convert the preselector to a buffer for use in finding indices
const toBuffer = Buffer.from(TO_PRESELECTOR);
const toIndex = Buffer.from(headerRemaining).indexOf(toBuffer);

let domainIndex: string | undefined;
let toAddrIndex: string | undefined; 

if (toIndex !== -1) {
  const emailStartIndex = toIndex + toBuffer.length; // Start after 'To:'
  const emailBuffer = Buffer.from(headerRemaining.slice(emailStartIndex)); // Remaining buffer after 'To:'

  // Regex match to extract the email domain
  const emailMatch = emailBuffer.toString().match(/[A-Za-z0-9!#$%&'*+=?\\-\\^_`{|}~./]+@([A-Za-z0-9.\\-]+)/);

  if (emailMatch && emailMatch[1]) {
    const domain = emailMatch[1];
    domainIndex = emailBuffer.indexOf(domain).toString(); // Assign the index of the domain in the buffer to domainIndex
    toAddrIndex = (toIndex + toBuffer.length).toString(); // Convert toAddrIndex to string for consistency
  } else {
    console.error("Domain not found");
  }
} else {
  console.error("'To:' field not found in the header");
}

  const address = bytesToBigInt(fromHex(ethereumAddress)).toString();

  return {
    ...emailVerifierInputs,
    toAddrIndex,
    domainIndex,
    address,
  };
}
