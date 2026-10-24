/** Strategyzer-style Value Proposition Canvas — data only, no UI. */

export type ValuePropositionCanvasLabels = {
  valueProposition?: string;
  customerSegment?: string;
  title?: string;
};

export type ValuePropositionCanvasNote = {
  title: string;
  note: string;
};

export type ValuePropositionCanvasFitRow = {
  from: string;
  to: string;
};

export type ValuePropositionCanvasData = {
  labels?: ValuePropositionCanvasLabels;
  productsAndServices: ValuePropositionCanvasNote[];
  gainCreators: ValuePropositionCanvasNote[];
  painRelievers: ValuePropositionCanvasNote[];
  customerJobs: ValuePropositionCanvasNote[];
  gains: ValuePropositionCanvasNote[];
  pains: ValuePropositionCanvasNote[];
  fit?: ValuePropositionCanvasFitRow[];
};
