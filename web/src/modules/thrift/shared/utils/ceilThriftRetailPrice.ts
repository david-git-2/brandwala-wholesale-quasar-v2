export function ceilThriftRetailPrice(price: number): number {
  if (!Number.isFinite(price) || price <= 0) return 50;
  const n = Math.ceil(price);
  let century = Math.floor(n / 100) * 100;
  while (true) {
    for (const ending of [50, 90]) {
      const candidate = century + ending;
      if (candidate >= n) return candidate;
    }
    century += 100;
  }
}
