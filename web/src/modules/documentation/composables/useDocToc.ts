import { ref } from 'vue';

export interface TouchHeading {
  id: string;
  text: string;
  level: number;
}

const headings = ref<TouchHeading[]>([]);

export function useDocToc() {
  const setHeadings = (list: TouchHeading[]) => {
    headings.value = list;
  };

  const clearHeadings = () => {
    headings.value = [];
  };

  return {
    headings,
    setHeadings,
    clearHeadings,
  };
}
