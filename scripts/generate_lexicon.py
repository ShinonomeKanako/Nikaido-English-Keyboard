#!/usr/bin/env python3
"""Generate a frozen offline lexicon from ESDB's US word-list and SymSpell counts."""
import argparse
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--american", type=Path, required=True)
parser.add_argument("--frequency", type=Path, required=True)
parser.add_argument("--esdb-revision", required=True)
parser.add_argument("--output", type=Path, default=Path("Resources/lexicon.tsv"))
args = parser.parse_args()
frequencies = {}
for line in args.frequency.read_text(encoding="utf-8-sig").splitlines():
    word, count = line.split()
    frequencies[word] = int(count)
valid = re.compile(r"[a-z](?:[a-z'-]*[a-z])?\Z")
# Exclude proper names/acronyms from default completion rather than silently lowercasing them.
words = {word for word in args.american.read_text().splitlines() if valid.fullmatch(word)}
words |= {"a", "i"}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text("# EnKeyBoard: ESDB US size 60, variant 1; SymSpell/Google Books frequencies.\n"
                      + "".join(f"{word}\t{frequencies.get(word, 1)}\n" for word in sorted(words)))
provenance = {
    "word_count": len(words),
    "esdb_revision": args.esdb_revision,
    "esdb_command": "./scowl word-list 60 A 1 --deaccent --categories= --no-word-filter",
    "esdb_source": "https://github.com/en-wl/wordlist",
    "frequency_source": "https://github.com/wolfgarbe/SymSpell/blob/master/SymSpell/frequency_dictionary_en_82_765.txt",
    "frequency_sha256": hashlib.sha256(args.frequency.read_bytes()).hexdigest(),
    "american_list_sha256": hashlib.sha256(args.american.read_bytes()).hexdigest(),
    "lexicon_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
    "modifications": "US word-list size 60, variant 1; ASCII lowercase entries, hyphens/apostrophes; missing frequencies use 1; no model or next-word prediction"
}
args.output.with_suffix(".provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
print(f"Generated {len(words)} US English entries")
