<template>
  <q-dialog
    v-model="isOpen"
    backdrop-filter="blur(4px)"
    transition-show="scale"
    transition-hide="scale"
    persistent
  >
    <q-card style="width: 480px; max-width: 95vw;" class="cloudinary-uploader-card floating-surface shadow-2 q-pa-md">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="text-h6 text-weight-bold row items-center">
          <q-icon name="cloud_upload" color="primary" class="q-mr-sm" size="sm" />
          Upload Image
        </div>
        <q-btn flat round dense icon="close" v-close-popup :disabled="uploading" />
      </q-card-section>

      <q-separator />

      <!-- Drag & Drop Zone / Preview Zone -->
      <q-card-section class="q-pt-md">
        <!-- Preview State -->
        <div v-if="previewUrl" class="preview-container text-center q-pa-sm relative-position">
          <q-img
            :src="previewUrl"
            spinner-color="primary"
            class="rounded-borders uploaded-preview"
            fit="contain"
          />
          <div class="file-info q-mt-sm text-caption text-grey-8">
            {{ selectedFile?.name }} ({{ formatBytes(selectedFile?.size || 0) }})
          </div>
          <q-btn
            round
            color="negative"
            icon="delete"
            size="sm"
            class="absolute-top-right q-ma-md"
            @click="clearSelection"
            :disabled="uploading"
          >
            <q-tooltip>Remove Image</q-tooltip>
          </q-btn>
        </div>

        <!-- Drag & Drop Zone -->
        <div
          v-else
          class="dropzone text-center q-pa-xl cursor-pointer"
          :class="{ 'dropzone--active': isDragActive }"
          @dragenter.prevent="isDragActive = true"
          @dragover.prevent="isDragActive = true"
          @dragleave.prevent="isDragActive = false"
          @drop.prevent="handleDrop"
          @click="triggerFilePicker"
        >
          <input
            type="file"
            ref="fileInput"
            accept="image/*"
            class="hidden"
            @change="handleFileChange"
          />
          <q-icon name="o_image" size="56px" color="grey-6" class="q-mb-md" />
          <div class="text-subtitle1 text-weight-medium text-grey-9">
            Drag and drop your image here
          </div>
          <div class="text-caption text-grey-6 q-mt-xs">
            or click to browse from your device
          </div>
        </div>

        <!-- Progress Bar -->
        <div v-if="uploading" class="q-mt-md">
          <div class="row justify-between text-caption text-grey-8 q-mb-xs">
            <div>Uploading to Cloudinary...</div>
            <div>{{ Math.round(uploadProgress) }}%</div>
          </div>
          <q-linear-progress :value="uploadProgress / 100" color="primary" class="q-mt-sm" />
        </div>
      </q-card-section>

      <!-- Action Buttons -->
      <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
        <q-btn
          flat
          no-caps
          label="Cancel"
          v-close-popup
          :disabled="uploading"
        />
        <q-btn
          color="primary"
          no-caps
          class="pill-btn slim-btn px-md"
          label="Upload Now"
          icon="cloud_upload"
          :loading="uploading"
          :disabled="!selectedFile"
          @click="uploadToCloudinary"
        />
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar } from 'quasar';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    folder?: string;
    maxWidth?: number;
    maxHeight?: number;
    quality?: number;
  }>(),
  {
    folder: '',
    maxWidth: 1200,
    maxHeight: 1200,
    quality: 0.8,
  }
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'uploaded', url: string, deleteToken?: string): void;
}>();

const $q = useQuasar();

// State
const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const isDragActive = ref(false);
const fileInput = ref<HTMLInputElement | null>(null);
const selectedFile = ref<File | null>(null);
const previewUrl = ref<string | null>(null);
const uploading = ref(false);
const uploadProgress = ref(0);

// Methods
function triggerFilePicker() {
  fileInput.value?.click();
}

function handleFileChange(event: Event) {
  const target = event.target as HTMLInputElement;
  if (target.files && target.files[0]) {
    setFile(target.files[0]);
  }
}

function handleDrop(event: DragEvent) {
  isDragActive.value = false;
  if (event.dataTransfer?.files && event.dataTransfer.files[0]) {
    const file = event.dataTransfer.files[0];
    if (file.type.startsWith('image/')) {
      setFile(file);
    } else {
      $q.notify({
        type: 'negative',
        message: 'Only image files are allowed',
      });
    }
  }
}

function setFile(file: File) {
  selectedFile.value = file;
  previewUrl.value = URL.createObjectURL(file);
}

function clearSelection() {
  selectedFile.value = null;
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
    previewUrl.value = null;
  }
  if (fileInput.value) {
    fileInput.value.value = '';
  }
}

function formatBytes(bytes: number, decimals = 2) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function resizeImage(file: File): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target?.result as string;
      img.onload = () => {
        let width = img.width;
        let height = img.height;

        // Calculate new dimensions matching max bounds and keeping ratio
        if (width > height) {
          if (width > props.maxWidth) {
            height = Math.round((height * props.maxWidth) / width);
            width = props.maxWidth;
          }
        } else {
          if (height > props.maxHeight) {
            width = Math.round((width * props.maxHeight) / height);
            height = props.maxHeight;
          }
        }

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('Failed to get 2D context from canvas'));
          return;
        }

        ctx.drawImage(img, 0, 0, width, height);

        canvas.toBlob(
          (blob) => {
            if (blob) {
              resolve(blob);
            } else {
              reject(new Error('Canvas toBlob failed'));
            }
          },
          file.type || 'image/jpeg',
          props.quality
        );
      };
      img.onerror = () => {
        reject(new Error('Failed to load image into object'));
      };
    };
    reader.onerror = () => {
      reject(new Error('Failed to read file source'));
    };
  });
}

async function uploadToCloudinary() {
  if (!selectedFile.value) return;

  const cloudName =
    import.meta.env.VITE_CLOUDINARY_CLOUD_NAME ||
    (process.env.VITE_CLOUDINARY_CLOUD_NAME as string);
  const uploadPreset =
    import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET ||
    (process.env.VITE_CLOUDINARY_UPLOAD_PRESET as string);

  if (!cloudName || !uploadPreset) {
    $q.notify({
      type: 'negative',
      message: 'Cloudinary configuration is missing. Check your environment variables.',
    });
    console.error('Missing VITE_CLOUDINARY_CLOUD_NAME or VITE_CLOUDINARY_UPLOAD_PRESET');
    return;
  }

  uploading.value = true;
  uploadProgress.value = 0;

  // Resize the image client-side before proceeding to upload
  let fileToUpload: File | Blob = selectedFile.value;
  try {
    fileToUpload = await resizeImage(selectedFile.value);
    console.log(
      `Original size: ${formatBytes(selectedFile.value.size)} -> Compressed size: ${formatBytes(fileToUpload.size)}`
    );
  } catch (resizeErr) {
    console.warn('Client-side resize failed, proceeding with original file:', resizeErr);
  }

  const url = `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`;
  const formData = new FormData();
  formData.append('file', fileToUpload, selectedFile.value.name);
  formData.append('upload_preset', uploadPreset);
  if (props.folder) {
    formData.append('folder', props.folder);
  }

  try {
    const xhr = new XMLHttpRequest();
    
    const promise = new Promise<{ secureUrl: string; deleteToken?: string }>((resolve, reject) => {
      xhr.open('POST', url, true);

      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          uploadProgress.value = (e.loaded / e.total) * 100;
        }
      };

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            const response = JSON.parse(xhr.responseText);
            resolve({
              secureUrl: response.secure_url,
              deleteToken: response.delete_token
            });
          } catch {
            reject(new Error('Failed to parse Cloudinary response'));
          }
        } else {
          try {
            const errRes = JSON.parse(xhr.responseText);
            reject(new Error(errRes.error?.message || 'Upload failed'));
          } catch {
            reject(new Error(`Upload failed with status ${xhr.status}`));
          }
        }
      };

      xhr.onerror = () => {
        reject(new Error('Network error during upload'));
      };

      xhr.send(formData);
    });

    const result = await promise;

    $q.notify({
      type: 'positive',
      message: 'Image uploaded successfully!',
    });

    emit('uploaded', result.secureUrl, result.deleteToken);
    clearSelection();
    isOpen.value = false;
  } catch (error: unknown) {
    $q.notify({
      type: 'negative',
      message: (error as Error).message || 'Image upload failed',
    });
    console.error('Cloudinary Upload Error:', error);
  } finally {
    uploading.value = false;
  }
}
</script>

<style scoped>
.cloudinary-uploader-card {
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(8px);
}

.dropzone {
  border: 2px dashed rgba(34, 56, 101, 0.2);
  border-radius: 12px;
  background: rgba(247, 249, 252, 0.6);
  transition: all 0.3s ease;
}

.dropzone:hover,
.dropzone--active {
  border-color: var(--q-primary);
  background: rgba(var(--q-primary-rgb, 25, 118, 210), 0.04);
}

.uploaded-preview {
  max-height: 220px;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.preview-container {
  border: 1px solid rgba(0, 0, 0, 0.05);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.5);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 36px;
}

.px-md {
  padding-left: 16px;
  padding-right: 16px;
}
</style>
