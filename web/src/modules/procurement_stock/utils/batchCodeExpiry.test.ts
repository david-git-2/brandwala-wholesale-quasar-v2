import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import {
  BATCH_EXPIRE_WARN_DAYS,
  batchExpiryRowClass,
  formatDaysAsMonthsAndDays,
  toIsoDate,
} from './batchCodeExpiry';

describe('toIsoDate', () => {
  test('parses Excel slash dates as M/D/YYYY', () => {
    expect(toIsoDate('6/27/2026')).toBe('2026-06-27');
    expect(toIsoDate('06/05/2026')).toBe('2026-06-05');
  });

  test('parses dashed dates as DD-MM-YYYY', () => {
    expect(toIsoDate('22-09-2026')).toBe('2026-09-22');
    expect(toIsoDate('05-06-2026')).toBe('2026-06-05');
  });

  test('accepts ISO', () => {
    expect(toIsoDate('2026-06-27')).toBe('2026-06-27');
  });
});

describe('formatDaysAsMonthsAndDays', () => {
  test('formats future time as months and days', () => {
    expect(formatDaysAsMonthsAndDays(45)).toBe('1mo 15d');
    expect(formatDaysAsMonthsAndDays(12)).toBe('12d');
    expect(formatDaysAsMonthsAndDays(60)).toBe('2mo');
  });

  test('shows Expired when due today or past', () => {
    expect(formatDaysAsMonthsAndDays(0)).toBe('Expired');
    expect(formatDaysAsMonthsAndDays(-45)).toBe('Expired');
  });
});

describe('batchExpiryRowClass', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-01T12:00:00'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  test('maps expiry to row tone classes', () => {
    expect(batchExpiryRowClass(null)).toBe('batch-row--unset');
    expect(batchExpiryRowClass('2027-04-01')).toBe('batch-row--warn');
    expect(batchExpiryRowClass('2027-08-15')).toBe('batch-row--ok');
    expect(batchExpiryRowClass('2026-05-01')).toBe('batch-row--warn');
  });

  test('uses same day threshold as 14mo display blocks', () => {
    expect(BATCH_EXPIRE_WARN_DAYS).toBe(420);
  });
});
