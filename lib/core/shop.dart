/// Lista della spesa furba: quantità e reparti.

class Dept {
  const Dept(this.key, this.icon, this.name, this.words);
  final String key;
  final String icon;
  final String name;
  final List<String> words;
}

/// Ordine = ordine di controllo (i più specifici prima).
const depts = <Dept>[
  Dept('surgelati', '❄️', 'Surgelati',
      ['surgel', 'gelato', 'gelati', 'bastoncini', 'ghiaccio', 'findus']),
  Dept('bevande', '🥤', 'Bevande', [
    'acqua', 'vino', 'birra', 'succo', 'succhi', 'coca', 'aranciata',
    'bibit', 'spumante', 'prosecco', 'tè freddo', 'the freddo', 'gassosa',
    'sprite', 'fanta', 'energy'
  ]),
  Dept('casa', '🧴', 'Casa e igiene', [
    'detersiv', 'sapone', 'shampoo', 'balsamo', 'bagnoschiuma', 'dentifric',
    'spazzolin', 'carta igienica', 'scottex', 'carta', 'sacchett', 'spugn',
    'ammorbident', 'candeggin', 'deodorant', 'assorbent', 'pannolin',
    'lavastoviglie', 'pastiglie', 'rotol', 'cotton', 'rasoi', 'lampadin',
    'pile', 'batterie', 'alluminio', 'pellicola', 'tovagliol', 'salviett',
    'fazzolett'
  ]),
  Dept('animali', '🐶', 'Animali',
      ['croccant', 'crocchett', 'lettiera', 'per cane', 'per gatto', 'scatolette']),
  Dept('carne', '🥩', 'Carne e pesce', [
    'pollo', 'manzo', 'maiale', 'carne', 'macinat', 'salsicc', 'bistecc',
    'tacchin', 'pesce', 'salmone', 'gamber', 'merluzz', 'hamburger',
    'vitello', 'agnello', 'cozze', 'vongol', 'orata', 'branzino', 'polpo',
    'calamar', 'cotolett', 'arrosto', 'fesa', 'petto'
  ]),
  Dept('frigo', '🧀', 'Frigo', [
    'latte', 'yogurt', 'yogourt', 'burro', 'formagg', 'mozzarell',
    'parmigian', 'grana', 'ricott', 'uova', 'uovo', 'panna', 'prosciutt',
    'salame', 'mortadell', 'wurstel', 'würstel', 'speck', 'bresaola',
    'stracchin', 'philadelphia', 'pancett', 'affettat', 'scamorz',
    'gorgonzol', 'pecorin', 'tofu', 'hummus', 'pasta fresca', 'gnocchi'
  ]),
  Dept('forno', '🍞', 'Pane e forno', [
    'pane', 'panin', 'focacc', 'piadin', 'cornett', 'brioche', 'biscott',
    'fette biscottate', 'cracker', 'grissin', 'torta', 'pancarr', 'tramezz',
    'croissant', 'muffin'
  ]),
  Dept('frutta', '🍎', 'Frutta e verdura', [
    'mela', 'mele', 'pera', 'pere', 'banan', 'aranc', 'limon', 'insalat',
    'pomodor', 'patat', 'cipoll', 'aglio', 'carot', 'zucchin', 'melanzan',
    'peperon', 'frutta', 'verdur', 'fragol', 'uva', 'kiwi', 'spinaci',
    'funghi', 'avocado', 'basilico', 'prezzemolo', 'rucola', 'lattuga',
    'finocch', 'sedano', 'broccol', 'cavol', 'pesche', 'pesca', 'ananas',
    'anguria', 'melone', 'mandarin', 'clementin', 'zucca', 'cetriol',
    'ravanell', 'asparag', 'carciof', 'menta', 'rosmarino', 'lime', 'mirtill',
    'lampon', 'ciliegi', 'albicocc', 'prugn', 'fichi', 'cocco'
  ]),
  Dept('dispensa', '🍝', 'Dispensa', [
    'pasta', 'spaghett', 'penne', 'fusilli', 'riso', 'farina', 'zucchero',
    'sale', 'olio', 'aceto', 'tonno', 'pelati', 'passata', 'sugo', 'pesto',
    'legumi', 'ceci', 'fagioli', 'lenticch', 'piselli', 'caffè', 'caffe',
    'cialde', 'capsule', 'tè', 'tisana', 'camomilla', 'cereali', 'muesli',
    'marmellat', 'confettur', 'nutella', 'miele', 'spezie', 'pepe', 'dado',
    'brodo', 'cioccolat', 'merend', 'snack', 'patatine', 'noci', 'mandorle',
    'arachidi', 'lievito', 'maionese', 'ketchup', 'senape', 'olive', 'mais',
    'cous cous', 'couscous', 'quinoa', 'avena', 'crema'
  ]),
];

const otherDept = Dept('altro', '📦', 'Altro', []);

Dept deptOf(String key) {
  for (final d in depts) {
    if (d.key == key) return d;
  }
  return otherDept;
}

Dept guessDept(String name) {
  final n = name.toLowerCase();
  for (final d in depts) {
    for (final w in d.words) {
      if (n.contains(w)) return d;
    }
  }
  return otherDept;
}

/// "2 latte", "2x latte", "latte x2", "latte ×2" → (2, "latte").
(int, String) parseQty(String raw) {
  final t = raw.trim();
  final a = RegExp(r'^(\d{1,3})\s*[x×]?\s+(.+)$', caseSensitive: false)
      .firstMatch(t);
  if (a != null) return (int.parse(a.group(1)!), a.group(2)!.trim());
  final b = RegExp(r'^(.+?)\s*[x×]\s*(\d{1,3})$', caseSensitive: false)
      .firstMatch(t);
  if (b != null) return (int.parse(b.group(2)!), b.group(1)!.trim());
  return (1, t);
}

/// Chiave sicura per i campi Firestore (niente punti o spazi).
String freqKey(String name) => name
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');
