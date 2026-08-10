import salesRoutes from './sales.routes';
import reportsRoutes from './reports.routes';
import ledgerRoutes from './ledger.routes';
import shipmentRoutes from './shipment.routes';
import boxRoutes from './box.routes';
import shelfRoutes from './shelf.routes';
import categoryRoutes from './category.routes';
import typeRoutes from './type.routes';
import stockRoutes from './stock.routes';
import barcodeRoutes from './barcode.routes';
import settingsRoutes from './settings.routes';
import stockTagRoutes from './stock-tag.routes';
import courierRoutes from './courier.routes';

export default [
  ...salesRoutes,
  ...courierRoutes,
  ...reportsRoutes,
  ...ledgerRoutes,
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

