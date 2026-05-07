#!/bin/zsh
set -euo pipefail

hidutil property --set '{
  "UserKeyMapping": [
    {
      "HIDKeyboardModifierMappingSrc": 0xC000000CF,
      "HIDKeyboardModifierMappingDst": 0x70000006D
    }
  ]
}'
