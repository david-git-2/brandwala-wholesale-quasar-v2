<template>
  <template v-if="!imageHidden">
    <img
      :src="currentImageSrc"
      :alt="alt"
      :class="imgClass"
      loading="lazy"
      referrerpolicy="no-referrer"
      @error="handleImageError"
    >
  </template>

  <template v-else>
    <div :class="fallbackClass">
      No Image
    </div>
  </template>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'

const props = withDefaults(defineProps<{
  src?: string | null
  alt?: string
  imgClass?: string
  fallbackClass?: string
}>(), {
  src: '',
  alt: 'Image',
  imgClass: '',
  fallbackClass: '',
})

const fallbackImage =
  'data:image/svg+xml;charset=UTF-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 800 450%27%3E%3Crect width=%27800%27 height=%27450%27 fill=%27%23f3efe9%27/%3E%3Ctext x=%27400%27 y=%27228%27 text-anchor=%27middle%27 font-family=%27Arial, sans-serif%27 font-size=%2732%27 fill=%27%23746655%27%3ENo Image%3C/text%3E%3C/svg%3E'

const imageAttempt = ref(0)
const imageHidden = ref(false)

const getDriveFileId = (url: string) => {
  const m1 = url.match(/[?&]id=([^&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  return m1?.[1] || m2?.[1] || null
}

const toDirectGoogleImageUrl = (url: string | null | undefined) => {
  if (!url) return ''
  const fileId = getDriveFileId(url)
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

const imageCandidates = computed(() => {
  const original = props.src || ''
  const direct = toDirectGoogleImageUrl(original)
  return [...new Set([direct, original, fallbackImage].filter(Boolean))]
})

const currentImageSrc = computed(() => {
  return imageCandidates.value[imageAttempt.value] || fallbackImage
})

watch(
  () => props.src,
  () => {
    imageAttempt.value = 0
    imageHidden.value = false
  },
  { immediate: true }
)

const handleImageError = () => {
  if (imageAttempt.value < imageCandidates.value.length - 1) {
    imageAttempt.value += 1
    return
  }

  imageHidden.value = true
}
</script>