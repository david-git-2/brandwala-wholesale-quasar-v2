<template>
  <q-dialog
    v-model="isOpen"
    backdrop-filter="blur(6px)"
    transition-show="scale"
    transition-hide="scale"
    maximized
    class="image-lightbox"
  >
    <div class="lightbox-container" @click="close">
      <!-- Top Action bar with download and close buttons -->
      <div class="lightbox-actions" @click.stop>
        <q-btn
          flat
          round
          dense
          color="white"
          icon="download"
          class="lightbox-btn"
          size="md"
          @click="downloadImage"
        >
          <q-tooltip class="bg-black text-white">Download Image</q-tooltip>
        </q-btn>
        <q-btn
          flat
          round
          dense
          color="white"
          icon="close"
          class="lightbox-btn"
          size="md"
          @click="close"
        >
          <q-tooltip class="bg-black text-white">Close</q-tooltip>
        </q-btn>
      </div>

      <!-- Main Image Display -->
      <div class="lightbox-content" @click.stop>
        <img
          :src="src"
          :alt="alt"
          class="lightbox-image"
        />
        <div v-if="alt" class="lightbox-caption">
          {{ alt }}
        </div>
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  modelValue: boolean
  src: string
  alt?: string
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void
}>()

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const close = () => {
  isOpen.value = false
}

const downloadImage = async () => {
  try {
    const response = await fetch(props.src)
    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    // Use alt text or filename from URL or default
    let filename = 'image.jpg'
    if (props.alt) {
      filename = `${props.alt.replace(/[^a-z0-9]/gi, '_').toLowerCase()}.jpg`
    } else {
      try {
        const urlObj = new URL(props.src)
        const pathname = urlObj.pathname
        const base = pathname.substring(pathname.lastIndexOf('/') + 1)
        if (base && base.includes('.')) {
          filename = base
        }
      } catch {
        // Ignore URL parsing errors and use default filename
      }
    }
    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
  } catch (err) {
    // Fallback if fetch fails (CORS issues)
    console.error('Failed to download image directly:', err)
    window.open(props.src, '_blank')
  }
}
</script>

<style scoped>
.lightbox-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100vw;
  height: 100vh;
  position: relative;
  background-color: rgba(0, 0, 0, 0.85);
  outline: none;
  overflow: hidden;
}

.lightbox-actions {
  position: absolute;
  top: 20px;
  right: 20px;
  display: flex;
  gap: 12px;
  z-index: 10;
}

.lightbox-btn {
  background: rgba(255, 255, 255, 0.15);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.lightbox-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: scale(1.1);
}

.lightbox-content {
  position: relative;
  max-width: 90%;
  max-height: 85%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  animation: zoomIn 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.lightbox-image {
  max-width: 100%;
  max-height: 80vh;
  width: auto;
  height: auto;
  object-fit: contain;
  border-radius: 8px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.lightbox-caption {
  margin-top: 16px;
  color: rgba(255, 255, 255, 0.9);
  font-size: 14px;
  letter-spacing: 0.5px;
  background: rgba(0, 0, 0, 0.6);
  padding: 8px 16px;
  border-radius: 20px;
  backdrop-filter: blur(5px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  text-align: center;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

@keyframes zoomIn {
  from {
    opacity: 0;
    transform: scale(0.9);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
</style>
