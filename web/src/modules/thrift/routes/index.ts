import salesRoutes from './sales.routes';
import reportsRoutes from './reports.routes';
import shipmentRoutes from './shipment.routes';
import boxRoutes from './box.routes';
import shelfRoutes from './shelf.routes';
import categoryRoutes from './category.routes';
import typeRoutes from './type.routes';
import stockRoutes from './stock.routes';
import barcodeRoutes from './barcode.routes';
import settingsRoutes from './settings.routes';
import stockTagRoutes from './stock-tag.routes';

export default [
  ...salesRoutes,
  ...reportsRoutes,
  ...shipmentRoutes,
  ...boxRoutes,
  ...shelfRoutes,
  ...categoryRoutes,
  ...typeRoutes,
  ...stockRoutes,
  ...barcodeRoutes,
  ...settingsRoutes,
  ...stockTagRoutes,
];

