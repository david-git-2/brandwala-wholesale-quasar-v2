import {
  MODULE_REGISTRY,
  type ModuleDefinition,
  type ModuleKey,
} from 'src/modules/navigation/moduleRegistry'

export const SEEDED_MODULE_DEFINITIONS: readonly ModuleDefinition[] = MODULE_REGISTRY

export const SEEDED_MODULE_KEYS = new Set<ModuleKey>(
  SEEDED_MODULE_DEFINITIONS.map((definition) => definition.key),
)

export const getSeededModuleDefinition = (moduleKey: string | null | undefined) =>
  SEEDED_MODULE_DEFINITIONS.find((definition) => definition.key === moduleKey) ?? null

export const isSeededModuleKey = (moduleKey: string | null | undefined) =>
  moduleKey !== null &&
  moduleKey !== undefined &&
  SEEDED_MODULE_KEYS.has(moduleKey as ModuleKey)
