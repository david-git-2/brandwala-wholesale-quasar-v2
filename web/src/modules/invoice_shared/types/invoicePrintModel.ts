export type InvoicePrintLine = {
  id: number | string
  name: string
  quantity: number
  unitPrice: number
  lineTotal: number
  imageUrl?: string | null | undefined
}

export type InvoicePrintCharge = {
  type: string
  label: string
  amount: number
}

export type InvoicePrintModel = {
  id: number
  invoiceNo: string
  invoiceDate: string
  invoiceType: string
  brandName: string
  brandAddress: string
  clientName: string
  clientTr?: string
  recipientName: string
  recipientPhone?: string | null
  recipientAddress?: string | null
  lines: InvoicePrintLine[]
  charges: InvoicePrintCharge[]
  subtotal: number
  discount: number
  total: number
  paid: number
  due: number
  thankYouMessage?: string
  isWholesale: boolean
  totalCost?: number
  profit?: number
  averageProfitRate?: string
}
