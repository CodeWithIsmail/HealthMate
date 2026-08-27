/// The tuning surface for redaction: every keyword and regex the detector
/// uses lives here, so `pii_detector.dart` stays pure logic.
///
/// Keywords are written as regex fragments (already escaped) because real lab
/// reports abbreviate inconsistently — "Ref. by", "Referred By", "Reg No.",
/// "Reg. No :". They are matched against a line that has been lowercased and
/// had its whitespace collapsed.
library;

/// What kind of personal detail a finding is. Drives the chips on the review
/// screen and which findings start out masked.
enum PiiCategory {
  identity,
  address,
  contact,
  identifier,
  clinician,
  facility,
  ageSex,

  /// A box the user drew themselves. Never auto-detected, always applied.
  manual,
}

extension PiiCategoryDisplay on PiiCategory {
  String get label => switch (this) {
    PiiCategory.identity => 'Name',
    PiiCategory.address => 'Address',
    PiiCategory.contact => 'Phone / email',
    PiiCategory.identifier => 'ID numbers',
    PiiCategory.clinician => 'Doctor',
    PiiCategory.facility => 'Lab / hospital',
    PiiCategory.ageSex => 'Age / sex',
    PiiCategory.manual => 'Added by you',
  };

  /// Age, DOB and sex are detected but left *unmasked* by default: they change
  /// how some reference ranges should be read, so the user opts in on the
  /// review screen rather than losing that context silently.
  bool get maskedByDefault => this != PiiCategory.ageSex;

  /// Whether the user is allowed to reveal a detected region again.
  ///
  /// Only age/sex — everything else identifies a person and stays masked no
  /// matter what. A privacy control that can be switched off protects only the
  /// users who already understood the risk, which is not who it is for.
  /// [PiiCategory.manual] is exempt because it is the user's own box: deleting
  /// something they added themselves reveals nothing that was detected.
  bool get canReveal => this == PiiCategory.ageSex || this == PiiCategory.manual;
}

/// Label fragments per category. A match means the **whole line** is masked —
/// safer than masking only the text after the colon, and it copes with
/// dot-leader layouts like `Name ................ Md. Rafiq`.
const Map<PiiCategory, List<String>> labelKeywords = {
  PiiCategory.identity: [
    r"name of (?:the )?(?:patient|client)",
    r"(?:patient|client|pt)'?s? name",
    r"patient",
    r"name",
    r"guardian",
    r"(?:father|mother|husband|wife|spouse)'?s? name",
    r"attendant",
  ],
  PiiCategory.address: [
    r'address',
    r'location',
    r'village',
    r'thana',
    r'upazila',
    r'union',
    r'district',
    r'post office',
    r'p\.?o\.? box',
    r'street',
    r'house no',
    r'holding no',
    r'city',
    r'zip',
    r'postcode',
    r'postal code',
  ],
  PiiCategory.contact: [
    r'phone',
    r'mobile',
    r'cell',
    r'contact',
    r'tel',
    r'telephone',
    r'e-?mail',
  ],
  PiiCategory.identifier: [
    r'patient id',
    r'patient no',
    r'id no',
    r'id#',
    r'reg\.? ?(?:no|id|number)',
    r'registration',
    r'm\.?r\.? ?(?:no|number)',
    r'mrn',
    r'hospital no',
    r'lab (?:no|id|serial)',
    r'(?:sample|specimen) (?:no|id)',
    r'accession',
    r'invoice',
    r'bill (?:no|number)',
    r'receipt',
    r'barcode',
    r'n\.?i\.?d\.?',
    r'national id',
    r'passport',
    r'card no',
  ],
  PiiCategory.clinician: [
    r'ref(?:erred|erring|\.)? ?by',
    r'ref(?:erence)? ?dr',
    r'consultant',
    r'requested by',
    r'physician',
    r'pathologist',
    r'signed by',
    r'verified by',
    r'reported by',
    r'under care of',
  ],
  PiiCategory.ageSex: [
    r'age',
    r'age ?/ ?sex',
    r'sex',
    r'gender',
    r'd\.?o\.?b\.?',
    r'date of birth',
    r'birth date',
  ],
};

/// Matched anywhere on a line, with no label needed. These are specific enough
/// to bypass the "this looks like a test result" guard.
final RegExp emailPattern = RegExp(r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}');

/// Bangladeshi mobile numbers: 01712345678, +8801712345678, 01712-345678.
///
/// The digit lookarounds matter: without them this pattern happily matches a
/// slice out of the middle of a lab value like `14000000000` (a WBC count in
/// full notation) and blacks out a result row.
final RegExp bdMobilePattern = RegExp(r'(?<!\d)(?:\+?88)?0?1[3-9]\d{2}[- ]?\d{6}(?!\d)');

/// Landlines and any other long dialled number. Deliberately requires a
/// separator and a leading 0/+ so it cannot swallow a plain lab value.
final RegExp genericPhonePattern = RegExp(r'(?<!\d)(?:\+|0)\d{3,}[- ]\d{3,}(?!\d)');

/// National ID / birth-registration numbers: runs of 10, 13 or 17 digits.
final RegExp nidPattern = RegExp(r'\b\d{10}(?:\d{3})?(?:\d{4})?\b');

/// A line that opens with a personal honorific is a name even without a label.
final RegExp honorificPattern = RegExp(r'^(?:mr|mrs|ms|miss|md|mst|most|mohd|mohammad)\b\.?\s+\S');

/// `Dr.`/`Prof.` anywhere means a clinician's name is on the line.
final RegExp doctorPattern = RegExp(r'\b(?:dr|prof|professor)\b\.?\s+\S');

/// Letterhead giveaways, matched anywhere on the page rather than only in the
/// top band.
///
/// "Pathology" and "imaging" are deliberately absent: they name a department as
/// often as a business ("PATHOLOGY REPORT"), and a facility line that really is
/// one almost always carries "lab", "centre" or "diagnostic" as well.
final RegExp facilityPattern = RegExp(
  r'\b(?:hospital|diagnostic|diagnostics|medical college|clinic|laborator(?:y|ies)|labs?|health ?care|centre|center)\b|www\.',
);

/// Report and department titles — `COMPLETE BLOOD COUNT`, `Haematology Report`.
///
/// These are set large and sit at the top of the page, so the "oversized line
/// near the top is a letterhead" rule would otherwise mask them. That matters
/// more now that facility boxes cannot be revealed again: masking the title
/// would silently cost the analysis its most useful line of context.
final RegExp reportTitlePattern = RegExp(
  r'\b(?:report|profile|panel|examination|investigation|haematolog\w*|hematolog\w*|biochem\w*|serolog\w*|microbiolog\w*|patholog\w*|immunolog\w*|urine|stool|blood|cbc|lipid|thyroid|liver|kidney|renal|glucose|sugar|analysis|screening|culture|x-?ray|ultrasonogram|ultrasound|result)\b',
);

/// Anything that looks like a date — used to keep the letterhead rule from
/// eating the collection/report date printed at the top of many reports.
final RegExp datePattern = RegExp(
  r'\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b',
);

/// Unit tokens that mark a line as a measurement. Paired with a digit, these
/// protect result rows from being masked.
const Set<String> unitTokens = {
  'mg/dl',
  'mg/l',
  'g/dl',
  'g/l',
  'gm/dl',
  'mmol/l',
  'umol/l',
  'µmol/l',
  'mmol',
  'meq/l',
  'iu/l',
  'u/l',
  'iu/ml',
  'miu/l',
  'µiu/ml',
  'uiu/ml',
  'ng/ml',
  'ng/dl',
  'pg/ml',
  'µg/dl',
  'ug/dl',
  'mm/hr',
  'mm/1st hr',
  'cells/cumm',
  '/cumm',
  '/µl',
  '/ul',
  'cu mm',
  'fl',
  'pg',
  '10^9/l',
  '10^12/l',
  'x10^9/l',
  'ratio',
  '%',
};

/// Two or more of these on one line means it is the results-table header row.
const Set<String> tableHeaderTokens = {
  'test',
  'investigation',
  'result',
  'results',
  'unit',
  'units',
  'reference',
  'range',
  'normal',
  'value',
  'method',
  'biological',
  'interval',
  'flag',
  'remarks',
};
