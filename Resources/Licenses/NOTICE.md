EnKeyBoard bundled lexicon attribution
=====================================

Word spellings and inflections: English Speller Database (ESDB, formerly
SCOWL), https://github.com/en-wl/wordlist, Copyright 2000–2026 Kevin Atkinson.
Generated US word list, size 60, variant level 1, no special categories;
ASCII lowercase entries with apostrophes/hyphens. See ESDB-Copyright.txt.

Frequency counts: frequency_dictionary_en_82_765.txt from SymSpell by
Wolf Garbe, https://github.com/wolfgarbe/SymSpell.
This data combines Google Books Ngram frequencies with SCOWL spellings.
See SymSpell-LICENSE.txt and SCOWL-v1-Copyright.txt for upstream notices.

Google Books Ngram data: Google, https://books.google.com/ngrams,
https://storage.googleapis.com/books/ngrams/books/datasetsv2.html.
Licensed under Creative Commons Attribution 3.0 Unported:
https://creativecommons.org/licenses/by/3.0/.
See CC-BY-3.0.txt for the license text.

EnKeyBoard modifications: counts were joined to the generated US word list;
entries without a frequency are assigned a fallback count of 1. Proper names,
non-ASCII entries, phrases and special-category entries are excluded. The
result is frozen as Resources/lexicon.tsv; hashes and ESDB revision are recorded
in Resources/lexicon.provenance.json. Personal words are stored separately.
The upstream SymSpell spelling-correction algorithm is not used.
