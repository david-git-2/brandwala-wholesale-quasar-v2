<template>
  <svg ref="svgRef" class="barcode-svg-element"></svg>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import JsBarcode from 'jsbarcode'

const props = defineProps<{
  value: string
  height?: number
  width?: number
  displayValue?: boolean
}>()

const svgRef = ref<SVGElement | null>(null)

const renderBarcode = () => {
  if (!svgRef.value || !props.value) return
  try {
    JsBarcode(svgRef.value, props.value, {
      format: 'CODE128',
      lineColor: '#000',
      width: props.width ?? 1.5,
      height: props.height ?? 40,
      displayValue: props.displayValue ?? false,
      margin: 0
    })
  } catch (err) {
    console.error('JsBarcode rendering error:', err)
  }
}

onMounted(() => {
  renderBarcode()
})

watch(() => props.value, () => {
  renderBarcode()
})
</script>

<style scoped>
.barcode-svg-element {
  width: 100%;
  height: 100%;
  max-height: 48px;
}
</style>
