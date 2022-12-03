import { IndexClient } from "candb-client-typescript/dist/IndexClient";
import { idlFactory as IndexCanisterIDL } from "../../declarations/database/index";
import { IndexCanister } from "../../declarations/database/database.did";
import { identityFromPemFile } from "candb-client-typescript/dist/ClientUtil"
import { homedir } from "os";
import path from "path";

interface CanisterIdMap {
  [key: string]: {
    local?: string;
    ic?: string;
  }
}

// Get main network canister ids
function getICCanisterIds(): CanisterIdMap {
  throw new Error("TODO: developer needs to replace this with the path to their main network canister_ids.json file")
}

// Get local canister ids
function getLocalCanisterIds(): CanisterIdMap {
  return require(path.resolve(
    "../",
    ".dfx",
    "local",
    "canister_ids.json"
  ));
}

export function initializeIndexClient(isLocal: boolean): IndexClient<IndexCanister> {
  const host = isLocal ? "http://127.0.0.1:8000" : "https://ic0.app";
  const canisterId = "rmc3i-vqaaa-aaaal-qbfqq-cai";
  return new IndexClient<IndexCanister>({
    IDL: IndexCanisterIDL,
    canisterId, 
    agentOptions: {
      host,
      // !! Recommended - for application management, you can use your locally generated identity to manage your canisters
      // This allows you to gate canister management (upgrade/deletion) APIs on the index canister by your identity
      //
      // See the options below on how to do this
      // 
      // 1. Pull in the identity from a pem file generated by dfx
      // identity: identityFromPemFile(`${homedir}/.config/dfx/identity/<your_identity>/identity.pem`),
      //
      // 2. Or pull in the identity from a seed phrase generated by quill
      //    To locally generate an identity with quill see steps 1-6 of https://forum.dfinity.org/t/using-dfinity-agent-in-node-js/6169/50
      // identity: await identityFromSeed(`${homedir}/.config/dfx/identity/<your_identity>/seed.txt`),
    },
  })
};