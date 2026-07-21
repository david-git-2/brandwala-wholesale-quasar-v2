import divisionsData from '../data/bd_address/divisions.json';
import districtsData from '../data/bd_address/districts.json';
import upazilasData from '../data/bd_address/upazilas.json';
import postcodesData from '../data/bd_address/postcodes.json';

export interface BDLocationOption {
  id: number;
  name: string;
  bnName: string;
  slug: string;
}

export interface BDPostcodeOption {
  id: number;
  districtId: number;
  upazilaId?: number | undefined;
  thanaId?: number | undefined;
  postOffice: string;
  postCode: string;
}

export interface RawDivision {
  id: string;
  name: string;
  bn_name?: string;
}

export interface RawDistrict {
  id: string;
  division_id: string;
  name: string;
  bn_name?: string;
}

export interface RawUpazila {
  id: string;
  district_id: string;
  name: string;
  bn_name?: string;
}

export interface RawPostcode {
  id: string;
  district_id: string;
  upazila_id?: string;
  thana_id?: string;
  post_office: string;
  post_code: string;
}

const divisions: BDLocationOption[] = (divisionsData as RawDivision[]).map((d) => ({
  id: Number(d.id),
  name: d.name,
  bnName: d.bn_name || '',
  slug: d.name.toLowerCase().replace(/\s+/g, '_'),
}));

const districts: BDLocationOption[] = (districtsData as RawDistrict[]).map((d) => ({
  id: Number(d.id),
  name: d.name,
  bnName: d.bn_name || '',
  slug: d.name.toLowerCase().replace(/\s+/g, '_'),
}));

const upazilas: BDLocationOption[] = (upazilasData as RawUpazila[]).map((u) => ({
  id: Number(u.id),
  name: u.name,
  bnName: u.bn_name || '',
  slug: u.name.toLowerCase().replace(/\s+/g, '_'),
}));

const postcodes: BDPostcodeOption[] = (postcodesData as RawPostcode[]).map((p) => ({
  id: Number(p.id),
  districtId: Number(p.district_id),
  upazilaId: p.upazila_id ? Number(p.upazila_id) : undefined,
  thanaId: p.thana_id ? Number(p.thana_id) : undefined,
  postOffice: p.post_office,
  postCode: p.post_code,
}));

/**
 * Get all 8 divisions of Bangladesh
 */
export async function getBDDivisions(): Promise<BDLocationOption[]> {
  return divisions;
}

/**
 * Get all 64 districts or filter by division ID / name
 */
export async function getBDDistricts(divisionIdOrSlug?: number | string): Promise<BDLocationOption[]> {
  if (divisionIdOrSlug === undefined || divisionIdOrSlug === null) {
    return districts;
  }

  let divIdStr: string | null = null;
  if (typeof divisionIdOrSlug === 'number') {
    divIdStr = String(divisionIdOrSlug);
  } else {
    const search = String(divisionIdOrSlug).toLowerCase().trim();
    const match = (divisionsData as RawDivision[]).find(
      (d) => d.name.toLowerCase() === search || (d.bn_name && d.bn_name.toLowerCase() === search)
    );
    if (match) divIdStr = match.id;
  }

  if (divIdStr) {
    const filtered = (districtsData as RawDistrict[]).filter((d) => d.division_id === divIdStr);
    return filtered.map((d) => ({
      id: Number(d.id),
      name: d.name,
      bnName: d.bn_name || '',
      slug: d.name.toLowerCase().replace(/\s+/g, '_'),
    }));
  }

  return districts;
}

/**
 * Get upazilas / thanas or filter by district ID / name
 */
export async function getBDUpazilas(districtIdOrSlug?: number | string): Promise<BDLocationOption[]> {
  if (districtIdOrSlug === undefined || districtIdOrSlug === null) {
    return upazilas;
  }

  let distIdStr: string | null = null;
  if (typeof districtIdOrSlug === 'number') {
    distIdStr = String(districtIdOrSlug);
  } else {
    const search = String(districtIdOrSlug).toLowerCase().trim();
    const match = (districtsData as RawDistrict[]).find(
      (d) => d.name.toLowerCase() === search || (d.bn_name && d.bn_name.toLowerCase() === search)
    );
    if (match) distIdStr = match.id;
  }

  if (distIdStr) {
    const filtered = (upazilasData as RawUpazila[]).filter((u) => u.district_id === distIdStr);
    return filtered.map((u) => ({
      id: Number(u.id),
      name: u.name,
      bnName: u.bn_name || '',
      slug: u.name.toLowerCase().replace(/\s+/g, '_'),
    }));
  }

  return upazilas;
}

/**
 * Get postcodes or filter by district ID / name or upazila / thana name
 */
export async function getBDPostcodes(
  districtIdOrSlug?: number | string,
  upazilaOrThanaName?: string
): Promise<BDPostcodeOption[]> {
  if (!districtIdOrSlug) {
    return postcodes;
  }

  let distIdStr: string | null = null;
  if (typeof districtIdOrSlug === 'number') {
    distIdStr = String(districtIdOrSlug);
  } else {
    const search = String(districtIdOrSlug).toLowerCase().trim();
    const match = (districtsData as RawDistrict[]).find(
      (d) => d.name.toLowerCase() === search || (d.bn_name && d.bn_name.toLowerCase() === search)
    );
    if (match) distIdStr = match.id;
  }

  if (!distIdStr) return postcodes;

  let filteredRaw = (postcodesData as RawPostcode[]).filter((p) => p.district_id === distIdStr);

  if (upazilaOrThanaName) {
    const uSearch = upazilaOrThanaName.toLowerCase().trim();
    const matchedUp = (upazilasData as RawUpazila[]).find(
      (u) => u.district_id === distIdStr && (u.name.toLowerCase() === uSearch || (u.bn_name && u.bn_name.toLowerCase() === uSearch))
    );
    if (matchedUp) {
      filteredRaw = filteredRaw.filter((p) => p.upazila_id === matchedUp.id || p.thana_id === matchedUp.id);
    }
  }

  return filteredRaw.map((p) => ({
    id: Number(p.id),
    districtId: Number(p.district_id),
    upazilaId: p.upazila_id ? Number(p.upazila_id) : undefined,
    thanaId: p.thana_id ? Number(p.thana_id) : undefined,
    postOffice: p.post_office,
    postCode: p.post_code,
  }));
}



