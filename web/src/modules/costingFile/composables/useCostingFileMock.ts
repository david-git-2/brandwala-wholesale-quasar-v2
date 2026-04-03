import { computed, reactive } from 'vue'

import { calculateCostingItem } from 'src/modules/costingFile/utils/costingCalculations'

export type CostingFileItemStatus = 'pending' | 'accepted' | 'rejected'

export type CostingFileItemDraft = {
  id: number
  websiteUrl: string
  quantity: number
  status: CostingFileItemStatus
  name: string
  imageUrl: string
  productWeight: number
  packageWeight: number
  webPriceGbp: number
  deliveryPriceGbp: number
  customerProfitRate: number
}

export type CostingFileDraft = {
  id: string
  name: string
  market: string
  status: string
  items: CostingFileItemDraft[]
}

type CreateFileForm = {
  name: string
  market: string
}

const mockState = reactive<{
  files: CostingFileDraft[]
  selectedFileId: string | null
  createFileForm: CreateFileForm
}>({
  files: [
    {
      id: 'CF-2402',
      name: 'April footwear sourcing',
      market: 'UK',
      status: 'in_review',
      items: [
        {
          id: 1,
          websiteUrl: 'https://www.example.com/product/running-shoe',
          quantity: 12,
          status: 'pending',
          name: 'Cushion runner sneaker',
          imageUrl: '',
          productWeight: 640,
          packageWeight: 180,
          webPriceGbp: 22.5,
          deliveryPriceGbp: 4.25,
          customerProfitRate: 12,
        },
      ],
    },
  ],
  selectedFileId: 'CF-2402',
  createFileForm: {
    name: '',
    market: '',
  },
})

let nextFileNumber = 2403
let nextItemId = 2

export const useCostingFileMock = () => {
  const files = computed(() => mockState.files)
  const selectedFile = computed(
    () => mockState.files.find((file) => file.id === mockState.selectedFileId) ?? null,
  )
  const createFileForm = mockState.createFileForm

  const fileListRows = computed(() =>
    mockState.files.map((file) => ({
      id: file.id,
      name: file.name,
      market: file.market,
      status: file.status,
      itemCount: file.items.length,
    })),
  )

  const productRows = computed(() =>
    (selectedFile.value?.items ?? []).map((item) => ({
      id: item.id,
      websiteUrl: item.websiteUrl,
      quantity: item.quantity,
      name: item.name || '-',
      status: item.status,
      productWeight: item.productWeight,
      packageWeight: item.packageWeight,
      offerPriceBdt: getItemMetrics(item).offerPriceBdt,
      buyerSellPriceBdt: getItemMetrics(item).buyerSellPrice,
    })),
  )

  const selectedItems = computed(() => selectedFile.value?.items ?? [])

  const selectFile = (fileId: string) => {
    mockState.selectedFileId = fileId
  }

  const createFile = () => {
    const name = createFileForm.name.trim()
    const market = createFileForm.market.trim().toUpperCase()

    if (!name || !market) {
      return false
    }

    const newFile: CostingFileDraft = {
      id: `CF-${nextFileNumber}`,
      name,
      market,
      status: 'draft',
      items: [],
    }

    nextFileNumber += 1
    mockState.files.unshift(newFile)
    mockState.selectedFileId = newFile.id
    createFileForm.name = ''
    createFileForm.market = ''

    return true
  }

  const addRequestItem = (websiteUrl: string, quantity: number) => {
    if (!selectedFile.value) {
      return false
    }

    const normalizedUrl = websiteUrl.trim()
    const normalizedQuantity = Math.max(1, Number(quantity || 1))

    if (!normalizedUrl) {
      return false
    }

    selectedFile.value.items.unshift({
      id: nextItemId,
      websiteUrl: normalizedUrl,
      quantity: normalizedQuantity,
      status: 'pending',
      name: '',
      imageUrl: '',
      productWeight: 0,
      packageWeight: 0,
      webPriceGbp: 0,
      deliveryPriceGbp: 0,
      customerProfitRate: 0,
    })

    nextItemId += 1
    return true
  }

  return {
    files,
    selectedFile,
    selectedItems,
    createFileForm,
    fileListRows,
    productRows,
    getItemMetrics,
    selectFile,
    createFile,
    addRequestItem,
  }
}

const getItemMetrics = (item: CostingFileItemDraft) =>
  calculateCostingItem(
    {
      cargoRate1Kg: 3.4,
      cargoRate2Kg: 2.85,
      conversionRate: 156,
      adminProfitRate: 18,
      offerPriceOverrideBdt: null,
    },
    {
      productWeight: item.productWeight,
      packageWeight: item.packageWeight,
      priceInWebGbp: item.webPriceGbp,
      deliveryPriceGbp: item.deliveryPriceGbp,
      customerProfitRate: item.customerProfitRate,
    },
  )
