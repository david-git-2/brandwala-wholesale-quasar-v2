<template>
  <div
    class="smart-image-wrapper"
    :class="[
      imageHidden ? fallbackClass : imgClass,
      { 'cursor-pointer': !imageHidden && enableLightbox }
    ]"
    @click="onWrapperClick"
  >
    <template v-if="!imageHidden">
      <img
        :src="currentImageSrc"
        :alt="alt"
        class="smart-image__img"
        :class="{ 'smart-image__img--loading': loadingImage }"
        loading="lazy"
        referrerpolicy="no-referrer"
        @error="handleImageError"
        @load="onImageLoad"
      >
      <q-inner-loading :showing="loadingImage" color="primary" class="smart-image-loading-overlay">
        <q-spinner-oval size="20px" />
      </q-inner-loading>
    </template>

    <template v-else>
      <div class="smart-image__fallback">
        No Image
      </div>
    </template>

    <!-- Admin Image Edit Button -->
    <q-btn
      v-if="isAdmin && enableEdit"
      round
      dense
      color="primary"
      icon="edit"
      size="sm"
      class="smart-image-edit-btn"
      @click.stop="openEditDialog"
    >
      <q-tooltip>Update Image URL</q-tooltip>
    </q-btn>

    <!-- Edit Image URL Dialog -->
    <q-dialog v-model="dialogOpen" @click.stop>
      <q-card style="width: 400px; max-width: 90vw;" class="q-pa-md">
        <q-card-section class="q-pa-none q-mb-md row items-center justify-between">
          <div class="text-subtitle1 text-weight-bold">Update Image URL</div>
          <q-btn flat round dense icon="close" size="sm" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-none q-mb-md">
          <q-input
            v-model="newUrl"
            label="Image URL"
            outlined
            dense
            autofocus
            class="q-mb-md"
            placeholder="https://example.com/image.jpg"
          />

          <!-- Live Preview of the entered URL -->
          <div class="text-caption text-grey-7 q-mb-xs">Preview:</div>
          <div class="preview-box border-grey rounded-borders flex flex-center q-pa-sm bg-grey-2" style="height: 180px; overflow: hidden;">
            <img
              v-if="newUrl && !previewError"
              :src="previewImageSrc"
              style="max-width: 100%; max-height: 100%; object-fit: contain;"
              @error="handlePreviewError"
              @load="previewError = false"
            />
            <div v-else class="text-grey-6 text-caption">No image preview</div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-none">
          <q-btn flat label="Cancel" v-close-popup no-caps />
          <q-btn
            color="primary"
            label="Update"
            :loading="updating"
            @click="onUpdate"
            no-caps
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Image Lightbox -->
    <ImageLightbox
      v-if="!imageHidden && enableLightbox"
      v-model="lightboxOpen"
      :src="currentImageSrc"
      :alt="alt"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { showSuccessNotification } from 'src/utils/appFeedback'
import ImageLightbox from 'src/components/ImageLightbox.vue'

const props = withDefaults(defineProps<{
  src?: string | null | undefined
  alt?: string
  imgClass?: string
  fallbackClass?: string
  productId?: number | string | null | undefined
  enableLightbox?: boolean
  enableEdit?: boolean
}>(), {
  src: '',
  alt: 'Image',
  imgClass: '',
  fallbackClass: '',
  productId: null,
  enableLightbox: true,
  enableEdit: true,
})

const emit = defineEmits<{
  (e: 'update:src', val: string): void
  (e: 'image-updated', val: string): void
}>()

const authStore = useAuthStore()
const isAdmin = computed(() => {
  return authStore.scope === 'app' && (authStore.matchedRole === 'admin' || authStore.matchedRole === 'superadmin')
})

const dialogOpen = ref(false)
const lightboxOpen = ref(false)

const onWrapperClick = () => {
  if (!imageHidden.value && props.enableLightbox) {
    lightboxOpen.value = true
  }
}
const newUrl = ref('')
const previewError = ref(false)
const updating = ref(false)

const fallbackImage =
  'data:image/svg+xml;charset=UTF-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 800 450%27%3E%3Crect width=%27800%27 height=%27450%27 fill=%27%23f3efe9%27/%3E%3Ctext x=%27400%27 y=%27228%27 text-anchor=%27middle%27 font-family=%27Arial, sans-serif%27 font-size=%2732%27 fill=%27%23746655%27%3ENo Image%3C/text%3E%3C/svg%3E'

const imageAttempt = ref(0)
const imageHidden = ref(false)
const loadingImage = ref(true)

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

const toProxyImageUrl = (url: string | null | undefined) => {
  if (!url) return ''
  const trimmed = url.trim()
  if (!trimmed || trimmed.startsWith('data:')) return trimmed

  let parsed: URL
  try {
    parsed = new URL(trimmed)
  } catch {
    return trimmed
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return trimmed
  }

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
  if (!supabaseUrl) return trimmed

  return `${supabaseUrl}/functions/v1/image-proxy?url=${encodeURIComponent(trimmed)}`
}

const imageCandidates = computed(() => {
  const original = props.src || ''
  const direct = toDirectGoogleImageUrl(original)
  const proxied = toProxyImageUrl(direct || original)
  return [...new Set([proxied, direct, original, fallbackImage].filter(Boolean))]
})

const currentImageSrc = computed(() => {
  return imageCandidates.value[imageAttempt.value] || fallbackImage
})

const previewAttempt = ref(0)
const previewCandidates = computed(() => {
  const original = newUrl.value || ''
  const direct = toDirectGoogleImageUrl(original)
  const proxied = toProxyImageUrl(direct || original)
  return [...new Set([proxied, direct, original].filter(Boolean))]
})
const previewImageSrc = computed(() => {
  return previewCandidates.value[previewAttempt.value] || ''
})

watch(
  () => props.src,
  () => {
    imageAttempt.value = 0
    imageHidden.value = false
    loadingImage.value = true
  },
  { immediate: true }
)

watch(newUrl, () => {
  previewAttempt.value = 0
  previewError.value = false
})

const onImageLoad = () => {
  loadingImage.value = false
}

const handleImageError = () => {
  if (imageAttempt.value < imageCandidates.value.length - 1) {
    imageAttempt.value += 1
    return
  }

  imageHidden.value = true
  loadingImage.value = false
}

const handlePreviewError = () => {
  if (previewAttempt.value < previewCandidates.value.length - 1) {
    previewAttempt.value += 1
  } else {
    previewError.value = true
  }
}

const openEditDialog = () => {
  newUrl.value = props.src || ''
  previewAttempt.value = 0
  previewError.value = false
  dialogOpen.value = true
}

const onUpdate = async () => {
  const updatedUrl = newUrl.value.trim()
  updating.value = true
  try {
    if (props.productId) {
      const { error } = await supabase
        .from('products')
        .update({ image_url: updatedUrl || null })
        .eq('id', props.productId)
      if (error) {
        throw error
      }
      showSuccessNotification('Product image updated successfully.')
    }
    emit('update:src', updatedUrl)
    emit('image-updated', updatedUrl)
    dialogOpen.value = false
  } catch (err) {
    console.error('Failed to update product image:', err)
  } finally {
    updating.value = false
  }
}
</script>

<style scoped>
.smart-image-wrapper {
  position: relative;
  overflow: hidden;
}

.smart-image__img {
  width: 100%;
  height: 100%;
  object-fit: inherit;
  display: block;
  border-radius: inherit;
  transition: filter 0.25s ease;
}

.smart-image-wrapper.cursor-pointer:hover .smart-image__img {
  filter: brightness(0.92);
}

.smart-image-edit-btn {
  position: absolute;
  top: 8px;
  right: 8px;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.25s ease, transform 0.2s ease;
  z-index: 10;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
}

.smart-image-wrapper:hover .smart-image-edit-btn {
  opacity: 1;
  pointer-events: auto;
}

.smart-image-edit-btn:hover {
  transform: scale(1.1);
}

.smart-image__fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #eef2f6;
  color: #78909c;
  border-radius: inherit;
}

.border-grey {
  border: 1px dashed #cfd8dc;
}

.smart-image__img--loading {
  filter: blur(4px);
  opacity: 0.5;
}

.smart-image-loading-overlay {
  background: rgba(255, 255, 255, 0.7) !important;
}
</style>
