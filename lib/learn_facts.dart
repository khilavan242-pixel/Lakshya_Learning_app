import 'learn_model.dart';

// ======================================================================
// MATHS & EVERYDAY FACTS for Quick Learn  (UKG - Class 5)
// Numbers 1-100 in English and Hindi, spellings, tables, add/subtract facts,
// squares, time, measures, shapes, colours, days, months ...
// ======================================================================

const List<String> _ones = <String>[
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
];
const List<String> _tens = <String>['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

String enWords(int n) {
  if (n < 20) return _ones[n];
  if (n < 100) {
    final t = _tens[n ~/ 10];
    final o = n % 10;
    return o == 0 ? t : '$t-${_ones[o]}';
  }
  if (n == 100) return 'one hundred';
  return n.toString();
}

const List<String> _hiWords = <String>[
  'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ', 'दस',
  'ग्यारह', 'बारह', 'तेरह', 'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह', 'उन्नीस', 'बीस',
  'इक्कीस', 'बाईस', 'तेईस', 'चौबीस', 'पच्चीस', 'छब्बीस', 'सत्ताईस', 'अट्ठाईस', 'उनतीस', 'तीस',
  'इकतीस', 'बत्तीस', 'तैंतीस', 'चौंतीस', 'पैंतीस', 'छत्तीस', 'सैंतीस', 'अड़तीस', 'उनतालीस', 'चालीस',
  'इकतालीस', 'बयालीस', 'तैंतालीस', 'चौवालीस', 'पैंतालीस', 'छियालीस', 'सैंतालीस', 'अड़तालीस', 'उनचास', 'पचास',
  'इक्यावन', 'बावन', 'तिरपन', 'चौवन', 'पचपन', 'छप्पन', 'सत्तावन', 'अट्ठावन', 'उनसठ', 'साठ',
  'इकसठ', 'बासठ', 'तिरसठ', 'चौंसठ', 'पैंसठ', 'छियासठ', 'सड़सठ', 'अड़सठ', 'उनहत्तर', 'सत्तर',
  'इकहत्तर', 'बहत्तर', 'तिहत्तर', 'चौहत्तर', 'पचहत्तर', 'छिहत्तर', 'सतहत्तर', 'अठहत्तर', 'उन्यासी', 'अस्सी',
  'इक्यासी', 'बयासी', 'तिरासी', 'चौरासी', 'पचासी', 'छियासी', 'सत्तासी', 'अट्ठासी', 'नवासी', 'नब्बे',
  'इक्यानवे', 'बानवे', 'तिरानवे', 'चौरानवे', 'पचानवे', 'छियानवे', 'सत्तानवे', 'अट्ठानवे', 'निन्यानवे', 'सौ',
];

String hiWords(int n) => (n >= 1 && n <= 100) ? _hiWords[n - 1] : n.toString();

String hiDigits(int n) {
  const d = '०१२३४५६७८९';
  return n.toString().split('').map((String c) => d[int.parse(c)]).join();
}

class LearnFacts {
  static List<LearnCard> _chunk(String title, List<List<String>> rows, int per, {bool math = false, String emoji = '🧮'}) {
    final out = <LearnCard>[];
    for (var i = 0; i < rows.length; i += per) {
      final end = i + per > rows.length ? rows.length : i + per;
      final label = rows.length > per ? '$title  (${i + 1}-$end)' : title;
      out.add(LearnCard(front: label, rows: rows.sublist(i, end), math: math, emoji: emoji));
    }
    return out;
  }

  static LearnSet _set(String group, String title, String emoji, List<LearnCard> cards) => LearnSet(title, emoji, cards, id: '', group: group);

  static List<LearnSet> all() {
    final out = <LearnSet>[];

    // ------------------------------------------------------------ NUMBERS
    {
      final rows = <List<String>>[for (var n = 1; n <= 100; n++) <String>['$n  ·  ${hiDigits(n)}', '${enWords(n)}  ·  ${hiWords(n)}']];
      out.add(_set('Numbers', '1-100 English & हिन्दी', '🔢', _chunk('Numbers', rows, 10)));
    }
    {
      final rows = <List<String>>[for (var n = 1; n <= 100; n++) <String>['$n', enWords(n)]];
      out.add(_set('Numbers', 'Number spellings (English)', '🔤', _chunk('Spell the number', rows, 10)));
    }
    {
      final rows = <List<String>>[for (var n = 1; n <= 100; n++) <String>['${hiDigits(n)}  ($n)', hiWords(n)]];
      out.add(_set('Numbers', 'हिन्दी गिनती १-१००', '🇮🇳', _chunk('हिन्दी गिनती', rows, 10)));
    }
    {
      const ord = <String>[
        'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth',
        'eleventh', 'twelfth', 'thirteenth', 'fourteenth', 'fifteenth', 'sixteenth', 'seventeenth', 'eighteenth', 'nineteenth', 'twentieth',
      ];
      String suf(int n) => n == 1 ? 'st' : (n == 2 ? 'nd' : (n == 3 ? 'rd' : 'th'));
      final rows = <List<String>>[for (var n = 1; n <= 20; n++) <String>['$n${suf(n)}', ord[n - 1]]];
      out.add(_set('Numbers', 'Ordinal numbers', '🥇', _chunk('1st, 2nd, 3rd ...', rows, 10)));
    }
    {
      const roman = <String>['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX'];
      final rows = <List<String>>[
        for (var n = 1; n <= 20; n++) <String>['$n', roman[n - 1]],
        <String>['30', 'XXX'],
        <String>['40', 'XL'],
        <String>['50', 'L'],
        <String>['100', 'C'],
      ];
      out.add(_set('Numbers', 'Roman numerals', '🏛️', _chunk('Roman numerals', rows, 12)));
    }
    out.add(_set('Numbers', 'Big numbers', '🏔️', <LearnCard>[
      const LearnCard(front: 'Big numbers', emoji: '🏔️', rows: <List<String>>[
        <String>['10', 'ten  ·  दस'],
        <String>['100', 'hundred  ·  सौ'],
        <String>['1,000', 'thousand  ·  हज़ार'],
        <String>['10,000', 'ten thousand  ·  दस हज़ार'],
        <String>['1,00,000', 'one lakh  ·  एक लाख'],
        <String>['10,00,000', 'ten lakh  ·  दस लाख'],
        <String>['1,00,00,000', 'one crore  ·  एक करोड़'],
      ]),
      const LearnCard(front: 'Place value', emoji: '🏠', rows: <List<String>>[
        <String>['Ones', '1'],
        <String>['Tens', '10'],
        <String>['Hundreds', '100'],
        <String>['Thousands', '1,000'],
        <String>['Ten thousands', '10,000'],
        <String>['Lakhs', '1,00,000'],
      ]),
    ]));
    {
      final rows = <List<String>>[for (var n = 1; n <= 20; n++) <String>['$n', n.isEven ? 'even number' : 'odd number']];
      out.add(_set('Numbers', 'Odd & even numbers', '⚖️', _chunk('Odd or even?', rows, 10)));
    }

    // ------------------------------------------------------------- TABLES
    {
      final cards = <LearnCard>[
        for (var n = 1; n <= 30; n++)
          LearnCard(front: 'Table of $n', rows: <List<String>>[for (var k = 1; k <= 10; k++) <String>['$n × $k =', '${n * k}']], math: true, emoji: '✖️'),
      ];
      out.add(_set('Tables', 'Multiplication tables 1-30', '✖️', cards));
    }
    {
      final cards = <LearnCard>[
        for (var n = 2; n <= 10; n++)
          LearnCard(front: 'Division by $n', rows: <List<String>>[for (var k = 1; k <= 10; k++) <String>['${n * k} ÷ $n =', '$k']], math: true, emoji: '➗'),
      ];
      out.add(_set('Tables', 'Division tables 2-10', '➗', cards));
    }

    // ----------------------------------------------------- ADD & SUBTRACT
    {
      final cards = <LearnCard>[
        for (var n = 1; n <= 10; n++)
          LearnCard(front: 'Add $n', rows: <List<String>>[for (var k = 1; k <= 10; k++) <String>['$n + $k =', '${n + k}']], math: true, emoji: '➕'),
      ];
      out.add(_set('Add & subtract', 'Addition facts 1-10', '➕', cards));
    }
    {
      final cards = <LearnCard>[
        for (var n = 1; n <= 10; n++)
          LearnCard(front: 'Take away $n', rows: <List<String>>[for (var k = 1; k <= 10; k++) <String>['${n + k} − $n =', '$k']], math: true, emoji: '➖'),
      ];
      out.add(_set('Add & subtract', 'Subtraction facts 1-10', '➖', cards));
    }
    {
      final rows10 = <List<String>>[for (var k = 0; k <= 10; k++) <String>['$k + ? = 10', '${10 - k}']];
      final rows20 = <List<String>>[for (var k = 0; k <= 20; k++) <String>['$k + ? = 20', '${20 - k}']];
      out.add(_set('Add & subtract', 'Number bonds (10 and 20)', '🤝', <LearnCard>[
        ..._chunk('Make 10', rows10, 11, math: true, emoji: '🤝'),
        ..._chunk('Make 20', rows20, 10, math: true, emoji: '🤝'),
      ]));
    }
    {
      final doubles = <List<String>>[for (var n = 1; n <= 20; n++) <String>['Double $n', '${n * 2}']];
      final halves = <List<String>>[for (var n = 1; n <= 20; n++) <String>['Half of ${n * 2}', '$n']];
      out.add(_set('Add & subtract', 'Doubles & halves', '👯', <LearnCard>[
        ..._chunk('Doubles', doubles, 10, emoji: '👯'),
        ..._chunk('Halves', halves, 10, emoji: '✂️'),
      ]));
    }

    // ----------------------------------------------------------- SQUARES
    out.add(_set('Squares & roots', 'Squares 1-30', '⚡', _chunk('Squares', <List<String>>[for (var n = 1; n <= 30; n++) <String>['$n² =', '${n * n}']], 10, math: true, emoji: '⚡')));
    out.add(_set('Squares & roots', 'Cubes 1-15', '🧊', _chunk('Cubes', <List<String>>[for (var n = 1; n <= 15; n++) <String>['$n³ =', '${n * n * n}']], 8, math: true, emoji: '🧊')));
    out.add(_set('Squares & roots', 'Square roots', '√', _chunk('Square roots', <List<String>>[for (var n = 1; n <= 20; n++) <String>['√${n * n} =', '$n']], 10, math: true, emoji: '√')));
    out.add(_set('Squares & roots', 'Fractions', '🍕', <LearnCard>[
      const LearnCard(front: 'Fractions', emoji: '🍕', rows: <List<String>>[
        <String>['1/2', 'one half'],
        <String>['1/3', 'one third'],
        <String>['1/4', 'one quarter'],
        <String>['2/4', 'two quarters = 1/2'],
        <String>['3/4', 'three quarters'],
        <String>['2/3', 'two thirds'],
        <String>['1/5', 'one fifth'],
        <String>['1/10', 'one tenth'],
      ]),
    ]));

    // ------------------------------------------------------ TIME & MEASURES
    out.add(_set('Time & measures', 'Days of the week', '📅', <LearnCard>[
      const LearnCard(front: 'Days of the week', emoji: '📅', rows: <List<String>>[
        <String>['1  Sunday', 'रविवार'],
        <String>['2  Monday', 'सोमवार'],
        <String>['3  Tuesday', 'मंगलवार'],
        <String>['4  Wednesday', 'बुधवार'],
        <String>['5  Thursday', 'गुरुवार'],
        <String>['6  Friday', 'शुक्रवार'],
        <String>['7  Saturday', 'शनिवार'],
      ]),
    ]));
    out.add(_set('Time & measures', 'Months of the year', '🗓️', <LearnCard>[
      const LearnCard(front: 'Months of the year', emoji: '🗓️', rows: <List<String>>[
        <String>['1  January', 'जनवरी'],
        <String>['2  February', 'फ़रवरी'],
        <String>['3  March', 'मार्च'],
        <String>['4  April', 'अप्रैल'],
        <String>['5  May', 'मई'],
        <String>['6  June', 'जून'],
        <String>['7  July', 'जुलाई'],
        <String>['8  August', 'अगस्त'],
        <String>['9  September', 'सितंबर'],
        <String>['10  October', 'अक्टूबर'],
        <String>['11  November', 'नवंबर'],
        <String>['12  December', 'दिसंबर'],
      ]),
    ]));
    out.add(_set('Time & measures', 'Time facts', '⏰', <LearnCard>[
      const LearnCard(front: 'Time facts', emoji: '⏰', rows: <List<String>>[
        <String>['1 minute', '60 seconds'],
        <String>['1 hour', '60 minutes'],
        <String>['1 day', '24 hours'],
        <String>['1 week', '7 days'],
        <String>['1 year', '12 months'],
        <String>['1 year', '365 days'],
        <String>['Leap year', '366 days'],
        <String>['1 decade', '10 years'],
        <String>['1 century', '100 years'],
      ]),
    ]));
    out.add(_set('Time & measures', 'Measurements', '📏', <LearnCard>[
      const LearnCard(front: 'Measurements', emoji: '📏', rows: <List<String>>[
        <String>['1 cm', '10 mm'],
        <String>['1 m', '100 cm'],
        <String>['1 km', '1000 m'],
        <String>['1 kg', '1000 g'],
        <String>['1 quintal', '100 kg'],
        <String>['1 tonne', '1000 kg'],
        <String>['1 litre', '1000 ml'],
        <String>['1 dozen', '12 things'],
        <String>['1 pair', '2 things'],
      ]),
    ]));

    // -------------------------------------------------- SHAPES & COLOURS
    out.add(_set('Shapes & colours', 'Shapes and sides', '🔷', <LearnCard>[
      const LearnCard(front: 'Shapes and sides', emoji: '🔷', rows: <List<String>>[
        <String>['Circle  ·  वृत्त', '0 corners (round)'],
        <String>['Triangle  ·  त्रिभुज', '3 sides'],
        <String>['Square  ·  वर्ग', '4 equal sides'],
        <String>['Rectangle  ·  आयत', '4 sides'],
        <String>['Pentagon  ·  पंचभुज', '5 sides'],
        <String>['Hexagon  ·  षट्भुज', '6 sides'],
        <String>['Heptagon  ·  सप्तभुज', '7 sides'],
        <String>['Octagon  ·  अष्टभुज', '8 sides'],
        <String>['Nonagon', '9 sides'],
        <String>['Decagon', '10 sides'],
      ]),
    ]));
    out.add(_set('Shapes & colours', 'Colours  English · हिन्दी', '🎨', <LearnCard>[
      const LearnCard(front: 'Colours', emoji: '🎨', rows: <List<String>>[
        <String>['Red', 'लाल'],
        <String>['Blue', 'नीला'],
        <String>['Green', 'हरा'],
        <String>['Yellow', 'पीला'],
        <String>['Orange', 'नारंगी'],
        <String>['Pink', 'गुलाबी'],
        <String>['Purple', 'बैंगनी'],
        <String>['Black', 'काला'],
        <String>['White', 'सफ़ेद'],
        <String>['Brown', 'भूरा'],
      ]),
    ]));
    out.add(_set('Shapes & colours', 'Maths words (opposites)', '↔️', <LearnCard>[
      const LearnCard(front: 'Maths opposites', emoji: '↔️', rows: <List<String>>[
        <String>['Add', 'Subtract'],
        <String>['Multiply', 'Divide'],
        <String>['More', 'Less'],
        <String>['Big', 'Small'],
        <String>['Long', 'Short'],
        <String>['Heavy', 'Light'],
        <String>['Odd', 'Even'],
        <String>['Greater than  >', 'Less than  <'],
      ]),
    ]));
    return out;
  }

  static List<String> groups(List<LearnSet> sets) {
    final out = <String>[];
    for (final s in sets) {
      if (!out.contains(s.group)) out.add(s.group);
    }
    return out;
  }
}
