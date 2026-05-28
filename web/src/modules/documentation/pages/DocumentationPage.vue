<template>
  <q-card flat bordered class="viewer-card full-height column no-wrap relative-position">
    <!-- Article Loading State -->
    <div v-if="loading" class="flex flex-center q-pa-xl col-grow">
      <div class="text-center">
        <q-spinner-tail color="primary" size="lg" />
        <div class="text-subtitle1 text-grey-7 q-mt-md">Fetching document content...</div>
      </div>
    </div>

    <!-- Document Content View -->
    <template v-else-if="activeDoc">
      <q-card-section class="q-pb-md border-bottom bg-surface-soft header-section">
        <div class="flex justify-between items-start no-wrap gap-md">
          <div>
            <div class="text-h5 text-weight-bold ink-color">{{ activeDoc.title }}</div>
            <div class="text-subtitle2 text-grey-6 q-mt-xs">{{ activeDoc.description }}</div>
          </div>
          <div v-if="activeDoc.moduleKey" class="active-badge flex items-center gap-xs no-shrink">
            <q-icon name="check_circle" size="xs" color="teal-6" />
            <span class="text-caption text-teal-8 text-weight-medium">Active Module</span>
          </div>
        </div>
      </q-card-section>

      <!-- Error Boundary: File Not Found -->
      <div v-if="loadError" class="q-pa-xl col-grow flex flex-center">
        <div v-if="loadError === 'NOT_FOUND'" class="text-center error-container q-pa-lg rounded-borders">
          <q-icon name="warning" color="warning" size="xl" class="q-mb-md" />
          <div class="text-h6 text-weight-bold text-warning-dark">Documentation File Not Created Yet</div>
          <p class="text-grey-8 q-my-md text-body2 max-width-p">
            The documentation file <code>{{ resolvedFilename }}</code> is not present in the workspace.
            To provide documentation for this module, simply create a file at that path.
          </p>
          <div class="bg-grey-2 q-pa-sm rounded-borders text-left font-mono text-caption text-grey-9 inline-block border-grey-3">
            $ touch "{{ resolvedFilename }}"
          </div>
        </div>
        <div v-else class="text-center">
          <q-icon name="error_outline" color="negative" size="xl" class="q-mb-md" />
          <div class="text-h6 text-negative text-weight-bold">Failed to Load Content</div>
          <p class="text-grey-7 q-mt-sm">{{ loadError }}</p>
        </div>
      </div>

      <!-- Markdown Display Pane -->
      <q-card-section v-else class="col-grow scrollable q-pa-lg">
        <article class="markdown-body" v-html="markdownHtml"></article>
      </q-card-section>
    </template>

    <!-- No Active Doc State -->
    <div v-else class="flex flex-center q-pa-xl col-grow text-center text-grey-6">
      <div>
        <q-icon name="library_books" size="xl" class="q-mb-sm" />
        <div class="text-h6">Select an article to begin reading</div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { marked } from 'marked'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { DOCUMENTATION_REGISTRY } from '../utils/docRegistry'
import { useDocToc, type TouchHeading } from '../composables/useDocToc'

const route = useRoute()
const { setHeadings, clearHeadings } = useDocToc()
const authStore = useAuthStore()

const activeDocKey = computed(() => {
  return (route.params.docKey as string) || ''
})

const activeDoc = computed(() => {
  if (!activeDocKey.value) return null
  return DOCUMENTATION_REGISTRY.find(d => d.key === activeDocKey.value) || null
})

const resolvedFilename = computed(() => {
  const doc = activeDoc.value
  if (!doc) return ''
  let filename = doc.filename
  if (filename.includes('{tenantId}')) {
    const tenantId = authStore.tenantId
    filename = filename.replace('{tenantId}', String(tenantId ?? 0))
  }
  return filename
})

const loading = ref(false)
const loadError = ref<string | null>(null)
const markdownHtml = ref('')

marked.setOptions({
  gfm: true,
  breaks: true,
})

const generateTableOfContents = async () => {
  await nextTick()
  const contentEl = document.querySelector('.markdown-body')
  if (!contentEl) {
    clearHeadings()
    return
  }

  const list: TouchHeading[] = []
  const headingElements = contentEl.querySelectorAll('h1, h2, h3')
  
  headingElements.forEach((el) => {
    const text = el.textContent || ''
    if (text.trim()) {
      let id = el.id
      if (!id) {
        id = text
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-+|-+$)/g, '')
        el.id = id
      }
      list.push({
        id,
        text,
        level: parseInt(el.tagName.replace('H', ''), 10),
      })
    }
  })
  setHeadings(list)
}

const loadDocContent = async () => {
  const doc = activeDoc.value
  if (!doc) {
    markdownHtml.value = ''
    clearHeadings()
    return
  }

  loading.value = true
  loadError.value = null
  markdownHtml.value = ''
  clearHeadings()
  
  try {
    const response = await fetch(`/${resolvedFilename.value}`)
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error('NOT_FOUND')
      }
      throw new Error(`Server returned status: ${response.status}`)
    }
    
    const rawText = await response.text()
    markdownHtml.value = await marked.parse(rawText)
    await generateTableOfContents()
  } catch (e) {
    const errorMsg = e instanceof Error ? e.message : String(e)
    if (errorMsg === 'NOT_FOUND') {
      loadError.value = 'NOT_FOUND'
    } else {
      loadError.value = errorMsg || 'An error occurred.'
    }
  } finally {
    loading.value = false
  }
}

watch(activeDoc, () => {
  void loadDocContent()
})

onMounted(() => {
  void loadDocContent()
})
</script>

<style lang="scss">
/* Custom reader typography for markdown elements */
.markdown-body {
  color: var(--bw-theme-ink);
  font-size: 15px;
  line-height: 1.6;

  h1, h2, h3, h4, h5, h6 {
    color: var(--bw-theme-ink);
    font-weight: 700;
    margin-top: 1.8rem;
    margin-bottom: 0.8rem;
    line-height: 1.25;
    scroll-margin-top: 100px;
  }

  h1 {
    font-size: 1.8rem;
    border-bottom: 1px solid var(--bw-theme-border);
    padding-bottom: 0.4rem;
  }

  h2 {
    font-size: 1.45rem;
    border-bottom: 1px solid var(--bw-theme-border);
    padding-bottom: 0.3rem;
  }

  h3 {
    font-size: 1.2rem;
  }

  p {
    margin-top: 0;
    margin-bottom: 1.1rem;
  }

  ul, ol {
    margin-top: 0;
    margin-bottom: 1.1rem;
    padding-left: 1.8rem;

    li {
      margin-bottom: 0.35rem;
    }
  }

  code {
    padding: 0.2rem 0.4rem;
    font-size: 85%;
    background-color: var(--bw-theme-primary-soft);
    color: var(--bw-theme-primary);
    border-radius: 6px;
    font-family: Consolas, Monaco, 'Andale Mono', monospace;
  }

  pre {
    padding: 1.2rem;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    background-color: var(--bw-theme-base);
    border: 1px solid var(--bw-theme-border);
    border-radius: 8px;
    margin-top: 0;
    margin-bottom: 1.1rem;
    
    code {
      padding: 0;
      background-color: transparent;
      color: var(--bw-theme-ink);
      font-size: inherit;
      border-radius: 0;
    }
  }

  blockquote {
    padding: 0.5rem 1rem;
    color: var(--bw-theme-muted);
    border-left: 4px solid var(--bw-theme-primary);
    background-color: var(--bw-theme-primary-soft);
    margin: 1.2rem 0;
    border-radius: 0 8px 8px 0;
    
    p:last-child {
      margin-bottom: 0;
    }
  }

  table {
    width: 100%;
    margin-top: 0;
    margin-bottom: 1.1rem;
    border-collapse: collapse;
    border-spacing: 0;
    
    th, td {
      padding: 8px 14px;
      border: 1px solid var(--bw-theme-border);
    }
    
    th {
      font-weight: 600;
      background-color: var(--bw-theme-primary-soft);
    }
    
    tr:nth-child(2n) {
      background-color: rgba(var(--bw-theme-primary-rgb), 0.02);
    }
  }

  hr {
    height: 1px;
    padding: 0;
    margin: 1.8rem 0;
    background-color: var(--bw-theme-border);
    border: 0;
  }
}
</style>
