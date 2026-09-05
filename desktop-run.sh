#!/bin/bash
# Wrapper used by the desktop shortcuts.
#
# A .desktop entry with Terminal=true closes its window the instant the command
# exits, which would make any output — including errors — unreadable. This runs
# the real script, then holds the window open.

"$@"
STATUS=$?

echo
if [ "$STATUS" -eq 0 ]; then
    echo -e "\033[0;32mFinished successfully.\033[0m"
else
    echo -e "\033[0;31mFinished with errors (exit code ${STATUS}).\033[0m"
fi
read -rp "Press Enter to close this window..."
exit "$STATUS"
