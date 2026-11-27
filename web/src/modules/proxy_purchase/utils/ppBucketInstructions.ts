import type { PpOrderLine } from '../types/ppPurchaseRequest';
import { ppOrderLineHostLabel } from './ppOrderLineUrl';

export const PP_BUCKET_INSTRUCTION_GENERAL = 'general' as const;

export type PpBucketInstructionStore = typeof PP_BUCKET_INSTRUCTION_GENERAL | string;

export type PpBucketInstruction = {
  store: PpBucketInstructionStore;
  description: string;
};

export type PpLineBucketInstructionDisplay = {
  storeLabel: string;
  description: string;
};

export function ppBucketInstructionStoreLabel(store: string): string {
  if (store === PP_BUCKET_INSTRUCTION_GENERAL) return 'General';
  return store;
}

export function ppBucketGeneralInstructionText(
  instructions: PpBucketInstruction[] | undefined,
): string | null {
  const hit = (instructions ?? []).find((e) => e.store === PP_BUCKET_INSTRUCTION_GENERAL);
  const text = hit?.description?.trim();
  return text || null;
}

export function parsePpBucketInstructions(value: unknown): PpBucketInstruction[] {
  if (!Array.isArray(value)) return [];
  const out: PpBucketInstruction[] = [];
  for (const item of value) {
    if (item == null || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    const store = typeof row.store === 'string' ? row.store.trim().toLowerCase() : '';
    const description = typeof row.description === 'string' ? row.description.trim() : '';
    if (!store || !description) continue;
    out.push({ store, description });
  }
  return out;
}

export function ppBucketInstructionsForLine(
  instructions: PpBucketInstruction[] | undefined,
  lineUrl: string,
): PpLineBucketInstructionDisplay[] {
  const list = instructions ?? [];
  if (!list.length) return [];

  const host = ppOrderLineHostLabel(lineUrl).trim().toLowerCase();
  const displays: PpLineBucketInstructionDisplay[] = [];

  if (host) {
    const storeHit = list.find((e) => e.store === host);
    if (storeHit) {
      displays.push({
        storeLabel: host,
        description: storeHit.description,
      });
    }
  }

  const general = list.find((e) => e.store === PP_BUCKET_INSTRUCTION_GENERAL);
  if (general) {
    displays.push({
      storeLabel: 'General',
      description: general.description,
    });
  }

  return displays;
}

export function distinctHostsFromLines(urls: readonly string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of urls) {
    const host = ppOrderLineHostLabel(raw).trim().toLowerCase();
    if (!host || seen.has(host)) continue;
    seen.add(host);
    out.push(host);
  }
  out.sort((a, b) => a.localeCompare(b));
  return out;
}

export const PP_REQUEST_OTHER_HOST = '__other__' as const;

export type PpRequestStoreSection = {
  key: string;
  label: string;
  instruction: PpBucketInstruction | null;
  lines: PpOrderLine[];
};

export function groupPpRequestLinesByStore(
  lines: readonly PpOrderLine[],
  instructions: readonly PpBucketInstruction[] | undefined,
): PpRequestStoreSection[] {
  const instrMap = new Map<string, PpBucketInstruction>();
  for (const item of instructions ?? []) {
    instrMap.set(item.store, item);
  }

  const linesByHost = new Map<string, PpOrderLine[]>();
  for (const line of lines) {
    const host = ppOrderLineHostLabel(line.url).trim().toLowerCase();
    const key = host || PP_REQUEST_OTHER_HOST;
    const bucket = linesByHost.get(key) ?? [];
    bucket.push(line);
    linesByHost.set(key, bucket);
  }

  const hostKeys = new Set<string>();
  for (const store of instrMap.keys()) {
    if (store !== PP_BUCKET_INSTRUCTION_GENERAL) hostKeys.add(store);
  }
  for (const key of linesByHost.keys()) {
    if (key !== PP_REQUEST_OTHER_HOST) hostKeys.add(key);
  }
  const sortedHosts = [...hostKeys].sort((a, b) => a.localeCompare(b));

  const sections: PpRequestStoreSection[] = [];

  const general = instrMap.get(PP_BUCKET_INSTRUCTION_GENERAL);
  if (general) {
    sections.push({
      key: PP_BUCKET_INSTRUCTION_GENERAL,
      label: ppBucketInstructionStoreLabel(PP_BUCKET_INSTRUCTION_GENERAL),
      instruction: general,
      lines: [],
    });
  }

  for (const host of sortedHosts) {
    sections.push({
      key: host,
      label: ppBucketInstructionStoreLabel(host),
      instruction: instrMap.get(host) ?? null,
      lines: linesByHost.get(host) ?? [],
    });
  }

  const otherLines = linesByHost.get(PP_REQUEST_OTHER_HOST);
  if (otherLines?.length) {
    sections.push({
      key: PP_REQUEST_OTHER_HOST,
      label: 'Other',
      instruction: null,
      lines: otherLines,
    });
  }

  return sections.filter((s) => s.instruction != null || s.lines.length > 0);
}

export function mergeBucketInstructionEntry(
  instructions: PpBucketInstruction[],
  store: string,
  description: string,
): PpBucketInstruction[] {
  const key = store.trim().toLowerCase();
  const desc = description.trim();
  const next = instructions.filter((e) => e.store !== key);
  if (desc) {
    next.push({ store: key, description: desc });
  }
  return next.sort((a, b) => {
    if (a.store === PP_BUCKET_INSTRUCTION_GENERAL) return -1;
    if (b.store === PP_BUCKET_INSTRUCTION_GENERAL) return 1;
    return a.store.localeCompare(b.store);
  });
}