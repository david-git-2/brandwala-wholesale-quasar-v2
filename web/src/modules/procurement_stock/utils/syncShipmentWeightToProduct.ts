import { productRepository } from 'src/modules/products/repositories/productRepository';

export async function syncShipmentWeightToProduct(
  productId: number | null,
  field: 'product_weight' | 'package_weight',
  value: number,
): Promise<void> {
  if (productId == null) return;

  try {
    await productRepository.updateProduct({
      id: productId,
      [field]: value,
    });
  } catch (error) {
    console.error(`Failed to sync ${field} to product ${productId}:`, error);
    // We do not throw or block the main shipment save, but we log the error
  }
}
