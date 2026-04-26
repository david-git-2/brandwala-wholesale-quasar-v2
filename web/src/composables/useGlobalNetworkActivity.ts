import { computed, ref } from 'vue'

const activeRequestCount = ref(0)

export const beginGlobalRequest = () => {
  activeRequestCount.value += 1
}

export const endGlobalRequest = () => {
  activeRequestCount.value = Math.max(0, activeRequestCount.value - 1)
}

export const useGlobalNetworkActivity = () => {
  const isActive = computed(() => activeRequestCount.value > 0)
  return {
    activeRequestCount,
    isActive,
  }
}
