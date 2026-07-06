import type { ProductBasedCostingFile, ProductBasedCostingItem } from '../types'
import {
  EXCEL_IMAGE_HEIGHT_PX,
  fetchImageForExcel,
  getExcelImageWidthPx,
} from './excelImageExport'

export type BuildCostingExcelInput = {
  file: ProductBasedCostingFile
  items: ProductBasedCostingItem[]
}

const FILL_WHITE = 'FFFFFFFF'
const FILL_PURPLE = 'FFE5DFEC'
const FILL_GREEN = 'FFC4E5AF'
const FILL_ORANGE = 'FFFFCC99'
const FONT_COURIER_GREEN = 'FF008080'
const FILL_FOOTER_TOTAL_WEIGHT = 'FF748C42'
const FILL_FOOTER_TOTAL_GOODS_COST = 'FFE5B8B7'
const FILL_FOOTER_TOTAL_COST_BDT = 'FF92CDDC'
const FILL_FOOTER_TOTAL_SELL = 'FF92D050'

const FONT_SIZE = 10
const SPACER_ROW_HEIGHT = 28.5
const HEADER_ROW_HEIGHT = 86.25
const DATA_ROW_HEIGHT = 100
const FOOTER_ROW_HEIGHT = 30
const FIRST_DATA_ROW_NUMBER = 3

const HEADERS = [
  'SL',
  'PICTURE',
  'PRODUCT',
  'Order Quantity',
  'Received Quantity',
  'ACTUALWEIGHT/PC IN G/ML',
  'Extra Weight / Pc for Carton',
  'WEIGHT/PC IN G/ML with Extra Weight',
  'TOTAL GOODS WEIGHT IN KG',
  'GOODS COST IN GBP',
  'TOTAL GOODS COST IN GBP',
  'COURIER COST IN GBP/KG',
  'TOTAL COST IN GBP/PC WITH COURIER',
  'TOTAL COST IN BDT/PC WITH COURIER',
  'TOTAL COST IN BDT',
  'SELL PX/PC IN BDT',
  'PROFIT/PCS',
  'TOTAL SELL PX IN BDT',
  'TOTAL PROFIT IN BDT',
  '% Profit',
  'REMARKS',
  'Barcode',
  'Product code',
] as const

const COLUMN_LETTERS = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W',
] as const

const COLUMN_WIDTHS = [
  3.6640625, 13.19921875, 16.19921875, 8.19921875, 8.19921875,
  6.46484375, 6.46484375, 7.59765625, 6.06640625, 7.86328125,
  6.59765625, 7.796875, 7.46484375, 8.19921875, 8.19921875,
  7.86328125, 6, 9.19921875, 8.19921875, 8,
  10, 8.6640625, 8.6640625,
]

const COLORED_COLUMNS: Record<string, string> = {
  G: FILL_PURPLE,
  J: FILL_GREEN,
  N: FILL_ORANGE,
  P: FILL_GREEN,
}

const COURIER_COLUMN_FONT_SIZE = 14
const PICTURE_COLUMN_INDEX = 1

const FONT_FAMILY = 'Arial'

const NUM_FMT_WEIGHT = '0'
const NUM_FMT_KG_GBP = '0.00'
const NUM_FMT_BDT = '0'
const NUM_FMT_PERCENT = '0.00'

const THIN_BORDER = { style: 'thin' as const }

const CELL_BORDER = {
  top: THIN_BORDER,
  left: THIN_BORDER,
  bottom: THIN_BORDER,
  right: THIN_BORDER,
}

const EMU_PER_PIXEL = 9525

const excelColumnWidthToPixels = (width: number) =>
  Math.floor(((width * 256 + Math.floor(128 / 7)) / 256) * 7)

const excelRowHeightToPixels = (heightPt: number) => heightPt * (96 / 72)

const pixelsToEmu = (px: number) => Math.round(px * EMU_PER_PIXEL)

type ExcelCell = {
  fill?: { type: 'pattern'; pattern: 'solid'; fgColor: { argb: string } }
  font?: { bold?: boolean; color?: { argb: string }; size?: number; name?: string }
  alignment?: { vertical: 'middle'; horizontal: 'center'; wrapText?: boolean }
  border?: {
    top?: { style: 'thin' }
    left?: { style: 'thin' }
    bottom?: { style: 'thin' }
    right?: { style: 'thin' }
  }
  numFmt?: string
  value?: string | number | { formula: string }
}

const solidFill = (argb: string) => ({
  type: 'pattern' as const,
  pattern: 'solid' as const,
  fgColor: { argb },
})

const applyCellStyle = (
  cell: ExcelCell,
  opts: {
    fillArgb?: string | undefined
    bold?: boolean | undefined
    numFmt?: string | undefined
    fontColorArgb?: string | undefined
    fontSize?: number | undefined
    center?: boolean | undefined
  } = {},
) => {
  if (opts.fillArgb) {
    cell.fill = solidFill(opts.fillArgb)
  }
  cell.alignment = {
    vertical: 'middle',
    horizontal: 'center',
    wrapText: true,
  }
  cell.font = {
    name: FONT_FAMILY,
    size: opts.fontSize ?? FONT_SIZE,
    ...(opts.bold ? { bold: true } : {}),
    ...(opts.fontColorArgb ? { color: { argb: opts.fontColorArgb } } : {}),
  }
  if (opts.numFmt) {
    cell.numFmt = opts.numFmt
  }
  cell.border = CELL_BORDER
}

const applyColoredColumnStyle = (
  row: { getCell: (col: string) => ExcelCell },
  cols: string[],
  bold = false,
) => {
  for (const col of cols) {
    const fillArgb = COLORED_COLUMNS[col]
    if (!fillArgb) continue

    applyCellStyle(row.getCell(col), {
      fillArgb,
      bold,
    })
  }
}

const applyRowGridBorders = (row: { getCell: (col: string) => ExcelCell }) => {
  for (const col of COLUMN_LETTERS) {
    row.getCell(col).border = CELL_BORDER
  }
}

const applyFooterRowStyle = (row: { getCell: (col: string) => ExcelCell }) => {
  for (const col of COLUMN_LETTERS) {
    applyCellStyle(row.getCell(col), { fillArgb: FILL_WHITE })
  }

  applyColoredColumnStyle(row, ['G', 'J', 'N', 'P'], false)

  applyCellStyle(row.getCell('I'), {
    fillArgb: FILL_FOOTER_TOTAL_WEIGHT,
    bold: true,
    numFmt: NUM_FMT_KG_GBP,
  })
  applyCellStyle(row.getCell('K'), {
    fillArgb: FILL_FOOTER_TOTAL_GOODS_COST,
    bold: true,
    numFmt: NUM_FMT_KG_GBP,
  })
  applyCellStyle(row.getCell('O'), {
    fillArgb: FILL_FOOTER_TOTAL_COST_BDT,
    bold: true,
    numFmt: NUM_FMT_BDT,
  })
  applyCellStyle(row.getCell('R'), {
    fillArgb: FILL_FOOTER_TOTAL_SELL,
    bold: true,
    numFmt: NUM_FMT_BDT,
  })
  applyCellStyle(row.getCell('S'), {
    fillArgb: FILL_WHITE,
    bold: true,
    numFmt: NUM_FMT_BDT,
  })
  applyCellStyle(row.getCell('T'), {
    fillArgb: FILL_WHITE,
    bold: true,
    numFmt: NUM_FMT_PERCENT,
  })
  applyCellStyle(row.getCell('C'), { bold: true })
}

const toNum = (value: number | null | undefined) =>
  value === null || value === undefined || Number.isNaN(Number(value)) ? 0 : Number(value)

const toWeight = (value: number | null | undefined) => Math.round(toNum(value))

export async function buildCostingExcelWorkbook(input: BuildCostingExcelInput) {
  const ExcelJS = await import('exceljs')
  const workbook = new ExcelJS.Workbook()
  const worksheet = workbook.addWorksheet('Costing Items')

  const conversionRate = input.file.conversion_rate ?? 140
  const cargoRate = input.file.cargo_rate_kg_gbp ?? 0
  const items = input.items

  COLUMN_WIDTHS.forEach((width, index) => {
    worksheet.getColumn(index + 1).width = width
  })

  const spacerRow = worksheet.addRow([])
  spacerRow.height = SPACER_ROW_HEIGHT
  applyRowGridBorders(spacerRow)

  const headerRow = worksheet.addRow([...HEADERS])
  headerRow.height = HEADER_ROW_HEIGHT
  headerRow.eachCell((cell) => {
    applyCellStyle(cell, { bold: true, fillArgb: FILL_WHITE })
  })
  applyColoredColumnStyle(headerRow, ['G', 'J', 'N', 'P'], true)

  const embeddedImages = await Promise.all(
    items.map((item) => fetchImageForExcel(item.image_url)),
  )

  const coloredCols = Object.keys(COLORED_COLUMNS)

  for (const [index, item] of items.entries()) {
    const r = index + FIRST_DATA_ROW_NUMBER
    const row = worksheet.addRow([
      index + 1,
      '',
      item.name ?? '',
      toNum(item.quantity),
      toNum(item.delivered_quantity),
      toWeight(item.product_weight),
      toWeight(item.package_weight),
      null,
      null,
      toNum(item.price_gbp),
      null,
      cargoRate,
      null,
      null,
      null,
      toNum(item.offer_price),
      null,
      null,
      null,
      null,
      item.note ?? '',
      item.barcode ?? '',
      item.product_code ?? '',
    ])

    row.getCell('H').value = { formula: `F${r}+G${r}` }
    row.getCell('I').value = { formula: `(D${r}*H${r})/1000` }
    row.getCell('K').value = { formula: `D${r}*J${r}` }
    row.getCell('M').value = { formula: `L${r}/1000*H${r}+J${r}` }
    row.getCell('N').value = { formula: `M${r}*${conversionRate}` }
    row.getCell('O').value = { formula: `D${r}*N${r}` }
    row.getCell('Q').value = { formula: `P${r}-N${r}` }
    row.getCell('R').value = { formula: `D${r}*P${r}` }
    row.getCell('S').value = { formula: `(P${r}-N${r})*D${r}` }
    row.getCell('T').value = { formula: `((P${r}-N${r})*100)/N${r}` }

    row.eachCell((cell) => {
      applyCellStyle(cell)
    })

    ;['F', 'G', 'H'].forEach((col) => {
      applyCellStyle(row.getCell(col), { numFmt: NUM_FMT_WEIGHT })
    })
    ;['I', 'J', 'K', 'M'].forEach((col) => {
      applyCellStyle(row.getCell(col), { numFmt: NUM_FMT_KG_GBP })
    })
    applyCellStyle(row.getCell('L'), {
      numFmt: NUM_FMT_KG_GBP,
      fontColorArgb: FONT_COURIER_GREEN,
      fontSize: COURIER_COLUMN_FONT_SIZE,
      bold: true,
    })
    ;['N', 'O', 'P', 'Q', 'R', 'S'].forEach((col) => {
      applyCellStyle(row.getCell(col), { numFmt: NUM_FMT_BDT })
    })
    applyCellStyle(row.getCell('T'), { numFmt: NUM_FMT_PERCENT })
    applyColoredColumnStyle(row, coloredCols)

    const embeddedImage = embeddedImages[index]
    if (embeddedImage) {
      const imageWidthPx = getExcelImageWidthPx(embeddedImage.width, embeddedImage.height)
      const pictureColumnWidthPx = excelColumnWidthToPixels(COLUMN_WIDTHS[PICTURE_COLUMN_INDEX] ?? 13.19921875)
      const rowHeightPx = excelRowHeightToPixels(DATA_ROW_HEIGHT)
      const colOff = pixelsToEmu(Math.max(0, (pictureColumnWidthPx - imageWidthPx) / 2))
      const rowOff = pixelsToEmu(Math.max(0, (rowHeightPx - EXCEL_IMAGE_HEIGHT_PX) / 2))

      const imageId = workbook.addImage({
        buffer: embeddedImage.buffer,
        extension: embeddedImage.extension,
      })

      worksheet.addImage(imageId, {
        tl: { col: PICTURE_COLUMN_INDEX, row: r - 1, colOff, rowOff },
        ext: { width: imageWidthPx, height: EXCEL_IMAGE_HEIGHT_PX },
      })
    }

    row.height = DATA_ROW_HEIGHT
  }

  if (items.length > 0) {
    const lastDataRow = items.length + FIRST_DATA_ROW_NUMBER - 1
    const totalRow = lastDataRow + 1
    const footerRow = worksheet.addRow([])

    footerRow.getCell('C').value = 'TOTAL'
    footerRow.getCell('I').value = { formula: `SUM(I${FIRST_DATA_ROW_NUMBER}:I${lastDataRow})` }
    footerRow.getCell('K').value = { formula: `SUM(K${FIRST_DATA_ROW_NUMBER}:K${lastDataRow})` }
    footerRow.getCell('O').value = { formula: `SUM(O${FIRST_DATA_ROW_NUMBER}:O${lastDataRow})` }
    footerRow.getCell('R').value = { formula: `SUM(R${FIRST_DATA_ROW_NUMBER}:R${lastDataRow})` }
    footerRow.getCell('S').value = { formula: `SUM(S${FIRST_DATA_ROW_NUMBER}:S${lastDataRow})` }
    footerRow.getCell('T').value = { formula: `(S${totalRow}*100)/O${totalRow}` }

    footerRow.height = FOOTER_ROW_HEIGHT
    applyFooterRowStyle(footerRow)
  }


  return workbook
}
