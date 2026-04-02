import { supabase } from 'src/boot/supabase'
import type {
  Module,
  ModuleCreateInput,
  ModuleDeleteInput,
  ModuleUpdateInput,
} from '../types'

const listModules = async (): Promise<Module[]> => {
  const { data, error } = await supabase
    .from('modules')
    .select('*')
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as Module[] | null) ?? []
}

const createModule = async (module: ModuleCreateInput): Promise<Module> => {
  const { data, error } = await supabase
    .from('modules')
    .insert([
      {
        key: module.key.trim().toLowerCase(),
        name: module.name.trim(),
        description: module.description.trim(),
        is_active: module.is_active,
      },
    ])
    .select()

  if (error) {
    throw error
  }

  const createdModule = Array.isArray(data) ? data[0] : data

  if (!createdModule) {
    throw new Error('Module was not created.')
  }

  return createdModule as Module
}

const updateModule = async (module: ModuleUpdateInput): Promise<Module> => {
  const { data, error } = await supabase
    .from('modules')
    .update({
      key: module.key.trim().toLowerCase(),
      name: module.name.trim(),
      description: module.description.trim(),
      is_active: module.is_active,
    })
    .eq('id', module.id)
    .select()

  if (error) {
    throw error
  }

  const updatedModule = Array.isArray(data) ? data[0] : data

  if (!updatedModule) {
    throw new Error('Module was not updated.')
  }

  return updatedModule as Module
}

const deleteModule = async (module: ModuleDeleteInput): Promise<Module> => {
  const { data, error } = await supabase
    .from('modules')
    .delete()
    .eq('id', module.id)
    .select()

  if (error) {
    throw error
  }

  const deletedModule = Array.isArray(data) ? data[0] : data

  if (!deletedModule) {
    throw new Error('Module was not deleted.')
  }

  return deletedModule as Module
}

export const moduleRepository = {
  listModules,
  createModule,
  updateModule,
  deleteModule,
}
