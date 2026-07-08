export type MeasurementGuideSection = 'tag' | 'core' | 'sleeves' | 'style_dims' | 'style_details';

export type MeasurementDiagramVariant = 'flatDress' | 'flatTop' | 'none';

export type MeasurementHighlight =
  | 'bust_in'
  | 'waist_in'
  | 'hips_in'
  | 'length_in'
  | 'shoulder_width_in'
  | 'sleeve_length_in'
  | 'arm_circumference_in'
  | 'hem_width_in'
  | 'neck_opening_in';

export type MeasurementGuideEntry = {
  key: string;
  label: string;
  section: MeasurementGuideSection;
  summary: string;
  howToMeasure: string;
  diagram: MeasurementDiagramVariant;
  highlight: MeasurementHighlight | '';
};

export const MEASUREMENT_GUIDE_SECTIONS: Array<{ id: MeasurementGuideSection; label: string }> = [
  { id: 'tag', label: 'Tag & fabric' },
  { id: 'core', label: 'Core fit' },
  { id: 'sleeves', label: 'Sleeves & structure' },
  { id: 'style_dims', label: 'Style dimensions' },
  { id: 'style_details', label: 'Style & details' },
];

export const MEASUREMENT_GUIDE_ENTRIES: MeasurementGuideEntry[] = [
  {
    key: 'size',
    label: 'Size (tag / label)',
    section: 'tag',
    summary: 'The size printed on the garment tag — not a tape measurement.',
    howToMeasure:
      'Read the label on the item (e.g. M, 10, 38, 32×30). Use this for quick reference; actual fit may differ by brand.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'fabric_stretch',
    label: 'Fabric stretch',
    section: 'tag',
    summary: 'How much the fabric stretches when pulled.',
    howToMeasure:
      'Pinch the fabric and pull gently. Choose none, low, medium, or high based on how much it gives and springs back.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'bust_in',
    label: 'Bust',
    section: 'core',
    summary: 'Width across the chest at armpit level (garment laid flat).',
    howToMeasure:
      'Lay the item flat. Measure straight across from underarm to underarm (pit to pit). Double this number for body circumference.',
    diagram: 'flatDress',
    highlight: 'bust_in',
  },
  {
    key: 'waist_in',
    label: 'Waist',
    section: 'core',
    summary: 'Width at the narrowest part of the torso on the garment.',
    howToMeasure:
      'Lay flat. Measure straight across at the natural waist seam or the narrowest point of the body of the garment.',
    diagram: 'flatDress',
    highlight: 'waist_in',
  },
  {
    key: 'hips_in',
    label: 'Hips',
    section: 'core',
    summary: 'Width at the fullest hip or seat area.',
    howToMeasure:
      'Lay flat. Measure straight across at the widest point around the hips, usually several inches below the waist on dresses and skirts.',
    diagram: 'flatDress',
    highlight: 'hips_in',
  },
  {
    key: 'length_in',
    label: 'Length',
    section: 'core',
    summary: 'Total length from top to bottom of the garment.',
    howToMeasure:
      'From the highest shoulder or neckline point straight down to the hem along the center front or back.',
    diagram: 'flatDress',
    highlight: 'length_in',
  },
  {
    key: 'shoulder_width_in',
    label: 'Shoulder width',
    section: 'sleeves',
    summary: 'Distance from shoulder seam to shoulder seam.',
    howToMeasure:
      'Lay flat with sleeves spread naturally. Measure straight across from one shoulder seam to the other.',
    diagram: 'flatTop',
    highlight: 'shoulder_width_in',
  },
  {
    key: 'sleeve_length_in',
    label: 'Sleeve length',
    section: 'sleeves',
    summary: 'Length from shoulder to cuff along the sleeve.',
    howToMeasure:
      'From the shoulder seam along the outer edge of the sleeve down to the cuff opening.',
    diagram: 'flatTop',
    highlight: 'sleeve_length_in',
  },
  {
    key: 'arm_circumference_in',
    label: 'Arm circumference',
    section: 'sleeves',
    summary: 'Around the sleeve opening (bicep or cuff area).',
    howToMeasure:
      'Measure around the sleeve at the point you are listing — often the cuff opening or the widest part of the upper arm.',
    diagram: 'flatTop',
    highlight: 'arm_circumference_in',
  },
  {
    key: 'hem_width_in',
    label: 'Hem width',
    section: 'style_dims',
    summary: 'Width across the bottom opening of the garment.',
    howToMeasure: 'Lay flat. Measure straight across from one side of the hem to the other.',
    diagram: 'flatDress',
    highlight: 'hem_width_in',
  },
  {
    key: 'neck_opening_in',
    label: 'Neck opening',
    section: 'style_dims',
    summary: 'Width of the neckline opening.',
    howToMeasure:
      'Lay flat. Measure straight across the neck opening at its widest point (not around the curve).',
    diagram: 'flatTop',
    highlight: 'neck_opening_in',
  },
  {
    key: 'sleeve_type',
    label: 'Sleeve type',
    section: 'style_details',
    summary: 'How the sleeves are constructed.',
    howToMeasure: 'Describe in words: set-in, raglan, cap, sleeveless, three-quarter, etc.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'neckline',
    label: 'Neckline',
    section: 'style_details',
    summary: 'Shape of the neck opening.',
    howToMeasure: 'Describe in words: crew, V-neck, scoop, boat, halter, etc.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'dress_style',
    label: 'Dress / garment style',
    section: 'style_details',
    summary: 'Overall silhouette or cut of the item.',
    howToMeasure: 'Describe in words: A-line, bodycon, shift, fit-and-flare, oversized, etc.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'closure_type',
    label: 'Closure type',
    section: 'style_details',
    summary: 'How the garment fastens.',
    howToMeasure: 'Describe in words: zipper, buttons, snap, pull-on, wrap, etc.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'lining',
    label: 'Has lining',
    section: 'style_details',
    summary: 'Whether an inner fabric layer is sewn inside the garment.',
    howToMeasure:
      'Check inside the garment. Lined items have a separate inner layer; unlined items show the back of the outer fabric.',
    diagram: 'none',
    highlight: '',
  },
  {
    key: 'measurement_notes',
    label: 'Notes',
    section: 'style_details',
    summary: 'Extra fit context for buyers or staff.',
    howToMeasure:
      'Free text for anything unusual: runs small, altered, missing button, stretchy fabric, etc.',
    diagram: 'none',
    highlight: '',
  },
];

export function guideEntriesForSection(section: MeasurementGuideSection): MeasurementGuideEntry[] {
  return MEASUREMENT_GUIDE_ENTRIES.filter((entry) => entry.section === section);
}
