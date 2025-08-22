import { describe, expect, it, vi, beforeEach } from "vitest";
import { Buffer } from "buffer";

// Types to represent Clarity-like data structures
type Buff32 = Uint8Array;
type Principal = string;
type Ok<T> = { type: "ok"; value: T };
type Err = { type: "err"; value: number };
type Result<T> = Ok<T> | Err;

interface WasteEntry {
  owner: Principal;
  timestamp: number;
  wasteType: string;
  origin: string;
  description: string;
  quantity: number;
  status: string;
}

interface Collaborator {
  role: string;
  permissions: string[];
  addedAt: number;
}

// Mock state
const wasteRegistry = new Map<string, WasteEntry>();
const wasteCollaborators = new Map<string, Collaborator>();
let blockHeight = 100;
let txSender: Principal = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";

// Mock helpers
const toBuff32 = (input: number[]): Buff32 => {
  if (input.length !== 32) throw new Error("Invalid buff32 length");
  return new Uint8Array(input);
};

const toHex = (buff: Buff32): string => Buffer.from(buff).toString("hex");

// Mock contract functions
const contract = {
  registerWaste: vi.fn(
    (
      hash: Buff32,
      wasteType: string,
      origin: string,
      description: string,
      quantity: number
    ): Result<boolean> => {
      const key = toHex(hash);
      if (wasteRegistry.has(key)) {
        return { type: "err", value: 1 }; // ERR-ALREADY-REGISTERED
      }
      wasteRegistry.set(key, {
        owner: txSender,
        timestamp: blockHeight,
        wasteType,
        origin,
        description,
        quantity,
        status: "registered",
      });
      return { type: "ok", value: true };
    }
  ),

  transferOwnership: vi.fn((hash: Buff32, newOwner: Principal): Result<boolean> => {
    const key = toHex(hash);
    const entry = wasteRegistry.get(key);
    if (!entry || entry.owner !== txSender) {
      return { type: "err", value: 2 }; // ERR-NOT-OWNER
    }
    wasteRegistry.set(key, { ...entry, owner: newOwner });
    return { type: "ok", value: true };
  }),

  addCollaborator: vi.fn(
    (hash: Buff32, collaborator: Principal, role: string, permissions: string[]): Result<boolean> => {
      const key = toHex(hash);
      const entry = wasteRegistry.get(key);
      if (!entry || entry.owner !== txSender) {
        return { type: "err", value: 2 }; // ERR-NOT-OWNER
      }
      wasteCollaborators.set(`${key}:${collaborator}`, { role, permissions, addedAt: blockHeight });
      return { type: "ok", value: true };
    }
  ),

  updateStatus: vi.fn((hash: Buff32, newStatus: string): Result<boolean> => {
    const key = toHex(hash);
    const entry = wasteRegistry.get(key);
    const collaborator = wasteCollaborators.get(`${key}:${txSender}`);
    if (!entry) {
      return { type: "err", value: 4 }; // ERR-NOT-FOUND
    }
    if (entry.owner !== txSender && (!collaborator || !collaborator.permissions.includes("update-status"))) {
      return { type: "err", value: 5 }; // ERR-PERMISSION-DENIED
    }
    wasteRegistry.set(key, { ...entry, status: newStatus });
    return { type: "ok", value: true };
  }),

  getWasteDetails: vi.fn((hash: Buff32): WasteEntry | undefined => {
    return wasteRegistry.get(toHex(hash));
  }),

  hasPermission: vi.fn((hash: Buff32, user: Principal, permission: string): boolean => {
    const collaborator = wasteCollaborators.get(`${toHex(hash)}:${user}`);
    return collaborator ? collaborator.permissions.includes(permission) : false;
  }),
};

describe("WasteRegistry Contract", () => {
  beforeEach(() => {
    // Reset mocks and state before each test
    wasteRegistry.clear();
    wasteCollaborators.clear();
    blockHeight = 100;
    txSender = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    vi.resetAllMocks();
  });

  it("successfully registers a new waste batch", () => {
    const hash = toBuff32(Array(32).fill(0));
    const result = contract.registerWaste(hash, "e-waste", "Factory A", "Old electronics", 100);
    expect(result).toEqual({ type: "ok", value: true });
    expect(contract.registerWaste).toHaveBeenCalledWith(
      hash,
      "e-waste",
      "Factory A",
      "Old electronics",
      100
    );
    const entry = contract.getWasteDetails(hash);
    expect(entry).toEqual({
      owner: txSender,
      timestamp: 100,
      wasteType: "e-waste",
      origin: "Factory A",
      description: "Old electronics",
      quantity: 100,
      status: "registered",
    });
  });

  it("fails to register duplicate waste batch", () => {
    const hash = toBuff32(Array(32).fill(0));
    contract.registerWaste(hash, "e-waste", "Factory A", "Old electronics", 100);
    const result = contract.registerWaste(hash, "e-waste", "Factory A", "Old electronics", 100);
    expect(result).toEqual({ type: "err", value: 1 }); // ERR-ALREADY-REGISTERED
    expect(contract.registerWaste).toHaveBeenCalledTimes(2);
  });

  it("transfers ownership successfully", () => {
    const hash = toBuff32(Array(32).fill(1));
    const newOwner = "ST2CY5AA2PATT6V3N1A3PB5CJ2YZ7M1B4N2V4N5V";
    contract.registerWaste(hash, "plastics", "Plant B", "Plastic bottles", 200);
    const result = contract.transferOwnership(hash, newOwner);
    expect(result).toEqual({ type: "ok", value: true });
    expect(contract.transferOwnership).toHaveBeenCalledWith(hash, newOwner);
    const entry = contract.getWasteDetails(hash);
    expect(entry?.owner).toBe(newOwner);
  });

  it("fails to transfer ownership if not owner", () => {
    const hash = toBuff32(Array(32).fill(1));
    const newOwner = "ST2CY5AA2PATT6V3N1A3PB5CJ2YZ7M1B4N2V4N5V";
    contract.registerWaste(hash, "plastics", "Plant B", "Plastic bottles", 200);
    txSender = "ST3F1G2H3J4K5M6N7P8Q9R0S1T2U3V4W5X6Y7Z8"; // Wrong sender
    const result = contract.transferOwnership(hash, newOwner);
    expect(result).toEqual({ type: "err", value: 2 }); // ERR-NOT-OWNER
  });

  it("adds collaborator and checks permission", () => {
    const hash = toBuff32(Array(32).fill(2));
    const collaborator = "ST2CY5AA2PATT6V3N1A3PB5CJ2YZ7M1B4N2V4N5V";
    contract.registerWaste(hash, "e-waste", "Factory C", "Circuit boards", 150);
    const result = contract.addCollaborator(hash, collaborator, "handler", ["update-status"]);
    expect(result).toEqual({ type: "ok", value: true });
    expect(contract.addCollaborator).toHaveBeenCalledWith(hash, collaborator, "handler", ["update-status"]);
    const hasPerm = contract.hasPermission(hash, collaborator, "update-status");
    expect(hasPerm).toBe(true);
  });

  it("updates status with collaborator permission", () => {
    const hash = toBuff32(Array(32).fill(3));
    const collaborator = "ST2CY5AA2PATT6V3N1A3PB5CJ2YZ7M1B4N2V4N5V";
    contract.registerWaste(hash, "e-waste", "Factory D", "Old monitors", 300);
    contract.addCollaborator(hash, collaborator, "handler", ["update-status"]);
    txSender = collaborator;
    const result = contract.updateStatus(hash, "collected");
    expect(result).toEqual({ type: "ok", value: true });
    expect(contract.updateStatus).toHaveBeenCalledWith(hash, "collected");
    const entry = contract.getWasteDetails(hash);
    expect(entry?.status).toBe("collected");
  });
});