import { useRoute } from 'vue-router';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { CostingFileDetails } from 'src/modules/costingFile/types';

type CostingDetailScope = 'admin' | 'staff' | 'viewer' | 'shop';

export function useCostingFileDetailBreadcrumbs(
  scope: CostingDetailScope,
  getSelectedFile: () => CostingFileDetails | null,
) {
  const route = useRoute();
  const authStore = useAuthStore();

  usePageBreadcrumbs(() => {
    const tenantSlug =
      authStore.tenantSlug || (route.params.tenantSlug as string | undefined) || null;

    if (scope === 'shop') {
      const listPath = tenantSlug ? `/${tenantSlug}/shop/costing` : '/shop/costing';
      return [
        {
          label: authStore.tenant?.name || 'Shop',
          icon: 'ph ph-storefront',
        },
        { label: 'Costing Files', to: listPath },
        { label: getSelectedFile()?.name || 'Costing file' },
      ];
    }

    const hubPath = tenantSlug ? `/${tenantSlug}/app/costing` : '/app/costing';
    const listPath = tenantSlug ? `/${tenantSlug}/app/costing/${scope}` : `/app/costing/${scope}`;
    const listLabel = scope === 'admin' ? 'Admin' : scope === 'staff' ? 'Staff' : 'Viewer';

    return [
      {
        label: authStore.selectedTenant?.name || 'Workspace',
        icon: 'ph ph-buildings',
      },
      { label: 'Costing Files', to: hubPath },
      { label: listLabel, to: listPath },
      { label: getSelectedFile()?.name || 'Costing file' },
    ];
  });
}
