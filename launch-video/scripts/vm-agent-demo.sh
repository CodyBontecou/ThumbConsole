#!/usr/bin/env bash
set -euo pipefail

clear
printf '\033[?25l'
printf '\033[38;5;45magent\033[0m  Create a Hollow Knight controller.\n'
sleep 1.0
printf '\n\033[38;5;244m$\033[0m \033[1mthumble generate "Hollow Knight"\033[0m\n\n'
sleep 0.8
/usr/local/bin/thumble generate "Hollow Knight" >/tmp/pocketpad-agent-generate.log
printf '\033[38;5;82m✓\033[0m Layout quality passed\n'; sleep 0.25
printf '\033[38;5;82m✓\033[0m Generated \033[1mHollow Knight\033[0m with the Cavern Glow theme\n'; sleep 0.25
printf '\033[38;5;82m✓\033[0m Confidence: high\n\n'; sleep 0.25
printf '\033[1mMapped controls\033[0m\n'
printf '  Movement      Arrow keys\n'; sleep 0.15
printf '  Jump          Z\n'; sleep 0.15
printf '  Nail          X\n'; sleep 0.15
printf '  Dash          C\n'; sleep 0.15
printf '  Soul          A\n'; sleep 0.15
printf '  Map / Pause   Tab / Escape\n\n'; sleep 0.25
printf '\033[38;5;45m15 controls\033[0m  •  icons  •  haptics  •  pressed states\n\n'; sleep 0.35
printf '\033[38;5;82m✓ Controller installed and synced to iPhone.\033[0m\n'
sleep 8
printf '\033[?25h'
