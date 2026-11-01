# OpenCC dictionary attribution

The six unmodified dictionary text files and LICENSE in this directory are from
OpenCC by BYVoid and contributors, release `ver.1.1.9` (Apache-2.0):
https://github.com/BYVoid/OpenCC/tree/ver.1.1.9/data/dictionary

Toolbox's independent Swift engine uses forward longest matching with the
dictionary stages described in the release's `data/config/s2twp.json`:
STPhrases + STCharacters → TWPhrasesIT + TWPhrasesName + TWPhrasesOther → TWVariants.
The three TWPhrases sources are the inputs merged by OpenCC's data/CMakeLists.txt.
When a dictionary entry has multiple alternatives, the first alternative is used.

This is not the OpenCC C++ runtime and does not claim exact equivalence to its
segmentation behavior. Conversion is line-local and tags interrupt matching;
phrases spanning subtitle lines, cue boundaries, or markup are not joined.
Human review remains appropriate for ambiguous words, names and specialized terminology.
No network access or external command is used at runtime.
