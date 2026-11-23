# Ressources

| Fichier | Source | Licence |
|---|---|---|
| `app/assets/fonts/Bungee-Regular.ttf` | [google/fonts — Bungee](https://github.com/google/fonts/tree/main/ofl/bungee) (David Jonathan Ross) | SIL OFL 1.1 (`OFL-Bungee.txt`) |
| `app/assets/fonts/Inter.ttf` | [google/fonts — Inter](https://github.com/google/fonts/tree/main/ofl/inter) (Rasmus Andersson) | SIL OFL 1.1 (`OFL-Inter.txt`) |

| `app/assets/audio/*.wav` (alarm, go, fin, highlight, tick, countdown, tap, hit, bounce, score, miss, whoosh) | Générés par synthèse avec `tools/gen_sfx.py` | Créés pour le projet, libres de droits |

| `app/assets/data/words_en.txt` | Liste ENABLE (« Enhanced North American Benchmark Lexicon »), filtrée 3–7 lettres | Domaine public |
| `app/assets/data/words_fr.txt` | [an-array-of-french-words](https://github.com/words/an-array-of-french-words) (Zeke Sikelianos), filtrée 3–7 lettres, sans accents | MIT (`LICENSE-french-words.txt`) |
| `app/assets/data/banned_words.json` | Copie de `shared/banned_words.json` (filtre de pseudos) | Créé pour le projet |

Pour régénérer les listes de mots : `python3 -I tools/build_wordlists.py enable1.txt index.json`.

Pour régénérer les sons : `python3 tools/gen_sfx.py` (nécessite numpy).
