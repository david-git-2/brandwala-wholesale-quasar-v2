import { ref } from 'vue';
import {
  getBDDistricts,
  getBDUpazilas,
  getBDPostcodes,
  type BDLocationOption,
  type BDPostcodeOption,
} from 'src/utils/bdAddressService';

export function useBDAddressOptions() {
  const rawDistricts = ref<BDLocationOption[]>([]);
  const rawThanas = ref<BDLocationOption[]>([]);
  const rawPostcodes = ref<(BDPostcodeOption & { displayLabel: string })[]>([]);

  const districtOptions = ref<BDLocationOption[]>([]);
  const thanaOptions = ref<BDLocationOption[]>([]);
  const postcodeOptions = ref<(BDPostcodeOption & { displayLabel: string })[]>([]);

  const loadInitialDistricts = async () => {
    rawDistricts.value = await getBDDistricts();
    districtOptions.value = rawDistricts.value;
  };

  const updatePostcodeList = async (distName: string, thanaName: string, currentPostCode?: string) => {
    if (!distName) {
      rawPostcodes.value = [];
      postcodeOptions.value = [];
      return;
    }
    const fetched = await getBDPostcodes(distName, thanaName);
    const mapped = fetched.map((p) => ({
      ...p,
      displayLabel: `${p.postOffice} - ${p.postCode}`,
    }));

    if (currentPostCode && !mapped.some((m) => m.postCode === currentPostCode)) {
      mapped.push({
        id: 0,
        districtId: 0,
        postOffice: currentPostCode,
        postCode: currentPostCode,
        displayLabel: currentPostCode,
      });
    }

    rawPostcodes.value = mapped;
    postcodeOptions.value = mapped;
  };

  const updateThanaList = async (distName: string, currentPostCode?: string) => {
    if (!distName) {
      rawThanas.value = await getBDUpazilas();
    } else {
      rawThanas.value = await getBDUpazilas(distName);
    }
    thanaOptions.value = rawThanas.value;
    await updatePostcodeList(distName, '', currentPostCode);
  };

  const filterDistrict = (val: string, update: (fn: () => void) => void) => {
    update(() => {
      const needle = val.toLowerCase().trim();
      if (!needle) {
        districtOptions.value = rawDistricts.value;
      } else {
        districtOptions.value = rawDistricts.value.filter(
          (d) =>
            d.name.toLowerCase().includes(needle) ||
            d.bnName.toLowerCase().includes(needle),
        );
      }
    });
  };

  const filterThana = (val: string, update: (fn: () => void) => void) => {
    update(() => {
      const needle = val.toLowerCase().trim();
      if (!needle) {
        thanaOptions.value = rawThanas.value;
      } else {
        thanaOptions.value = rawThanas.value.filter(
          (t) =>
            t.name.toLowerCase().includes(needle) ||
            t.bnName.toLowerCase().includes(needle),
        );
      }
    });
  };

  const filterPostcode = (val: string, update: (fn: () => void) => void) => {
    update(() => {
      const needle = val.toLowerCase().trim();
      if (!needle) {
        postcodeOptions.value = rawPostcodes.value;
      } else {
        postcodeOptions.value = rawPostcodes.value.filter(
          (p) =>
            p.postCode.toLowerCase().includes(needle) ||
            p.postOffice.toLowerCase().includes(needle),
        );
      }
    });
  };

  const createPostcode = (val: string, done: (item: any) => void) => {
    const custom = {
      id: 0,
      districtId: 0,
      postOffice: val,
      postCode: val,
      displayLabel: val,
    };
    done(custom);
  };

  return {
    districtOptions,
    thanaOptions,
    postcodeOptions,
    loadInitialDistricts,
    updateThanaList,
    updatePostcodeList,
    filterDistrict,
    filterThana,
    filterPostcode,
    createPostcode,
  };
}
