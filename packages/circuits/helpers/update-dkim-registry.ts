import { ethers, JsonRpcProvider } from "ethers";
import { buildPoseidon } from "circomlibjs";
import dns from "dns";
import path from "path";
import forge from "node-forge";
const fs = require("fs");
import { poseidonLarge } from "@zk-email/helpers/src/hash";
require("dotenv").config();

export async function getPublicKeyForDomainAndSelector(
  domain: string,
  selector: string,
  print: boolean = true
) {
  // Construct the DKIM record name
  let dkimRecordName = `${selector}._domainkey.${domain}`;
  if (print) console.log(dkimRecordName);
  // Lookup the DKIM record in DNS
  let records;
  try {
    records = await dns.promises.resolveTxt(dkimRecordName);
  } catch (err) {
    if (print) console.error(err);
    return;
  }

  if (!records.length) {
    return;
  }

  // The DKIM record is a TXT record containing a string
  // We need to parse this string to get the public key
  let dkimRecord = records[0].join("");
  let match = dkimRecord.match(/p=([^;]+)/);
  if (!match) {
    console.error(`No public key found in DKIM record for ${domain}`);
    return;
  }

  // The public key is base64 encoded, we need to decode it
  let pubkey = match[1];
  let binaryKey = Buffer.from(pubkey, "base64").toString("base64");

  // Get match
  let matches = binaryKey.match(/.{1,64}/g);
  if (!matches) {
    console.error("No matches found");
    return;
  }
  let formattedKey = matches.join("\n");
  if (print) console.log("Key: ", formattedKey);

  // Convert to PEM format
  let pemKey = `-----BEGIN PUBLIC KEY-----\n${formattedKey}\n-----END PUBLIC KEY-----`;

  // Parse the RSA public key
  let publicKey = forge.pki.publicKeyFromPem(pemKey);

  // Get the modulus n only
  let n = publicKey.n;
  if (print) console.log("Modulus n:", n.toString(16));

  return BigInt(publicKey.n.toString());
}

async function checkSelector(domain: string, selector: string) {
  try {
    const publicKey = await getPublicKeyForDomainAndSelector(
      domain,
      selector,
      false
    );
    if (publicKey) {
      console.log(`Domain: ${domain}, Selector: ${selector} - Match found`);
      return {
        match: true,
        selector: selector,
        domain: domain,
        publicKey,
      };
    } else {
      // console.log(`Domain: ${domain}, Selector: ${selector} - No match found`);
    }
  } catch (error) {
    console.error(
      `Error processing domain: ${domain}, Selector: ${selector} - ${error}`
    );
  }

  return {
    match: false,
    selector: selector,
    domain: domain,
    publicKey: null,
  };
}

// Filename is a file where each line is a domain
// This searches for default selectors like "google" or "default"
async function getDKIMPublicKeysForDomains(filename: string) {
  const domains = fs.readFileSync(filename, "utf8").split("\n");
  const selectors = [
    "google",
    "default",
    "mail",
    "smtpapi",
    "dkim",
    "200608",
    "20230601",
    "20221208",
    "20210112",
    "dkim-201406",
    "1a1hai",
    "v1",
    "v2",
    "v3",
    "k1",
    "k2",
    "k3",
    "hs1",
    "hs2",
    "s1",
    "s2",
    "s3",
    "sig1",
    "sig2",
    "sig3",
    "selector",
    "selector1",
    "selector2",
    "mindbox",
    "bk",
    "sm1",
    "sm2",
    "gmail",
    "10dkim1",
    "11dkim1",
    "12dkim1",
    "memdkim",
    "m1",
    "mx",
    "sel1",
    "bk",
    "scph1220",
    "ml",
    "pps1",
    "scph0819",
    "skiff1",
    "s1024",
    "selector1",
    "dkim-202308",
  ];

  let results = [];

  for (let domain of domains) {
    const promises = [];
    for (let selector of selectors) {
      promises.push(checkSelector(domain, selector));
    }
    results.push(...(await Promise.all(promises)));
  }

  const matchedSelectors: {
    [key: string]: { publicKey: string; selector: string }[];
  } = {};

  for (let result of results) {
    if (result.match && result.publicKey) {
      if (!matchedSelectors[result.domain]) {
        matchedSelectors[result.domain] = [];
      }

      const publicKey = result.publicKey.toString();

      if (
        !matchedSelectors[result.domain].find((d) => d.publicKey === publicKey)
      ) {
        matchedSelectors[result.domain].push({
          selector: result.selector,
          publicKey,
        });
      }
    }
  }

  return matchedSelectors;
}
