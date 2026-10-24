import type { ValuePropositionCanvasData } from 'src/components/ui/valuePropositionCanvas.types';
import type { PlatformVpcData } from './parsePlatformVpcMd';

export function mapPlatformVpcToCanvas(
  data: PlatformVpcData,
  labels?: ValuePropositionCanvasData['labels'],
): ValuePropositionCanvasData {
  return {
    labels: {
      title: labels?.title ?? 'The Value Proposition Canvas',
      valueProposition: labels?.valueProposition ?? data.labels.valueProposition,
      customerSegment: labels?.customerSegment ?? data.labels.customerSegment,
      ...labels,
    },
    productsAndServices: data.products,
    customerJobs: data.jobs,
    pains: data.pains,
    gains: data.gains,
    painRelievers: data.painRelievers,
    gainCreators: data.gainCreators,
    fit: data.fit.map((row) => ({ from: row.left, to: row.right })),
  };
}
