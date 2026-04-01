export type Module = {
  id: number
  key: string
  name: string
  description: string
  is_active: boolean
  created_at?: string
  updated_at?: string
}

export type ModuleCreateInput = {
  key: string
  name: string
  description: string
  is_active: boolean
}

export type ModuleUpdateInput = {
  id: number
  key: string
  name: string
  description: string
  is_active: boolean
}

export type ModuleDeleteInput = {
  id: number
}

export type ModuleServiceResult<T> = {
  success: boolean
  data?: T
  error?: string
}

export type ModuleStoreState = {
  items: Module[]
  loading: boolean
  error: string | null
}
