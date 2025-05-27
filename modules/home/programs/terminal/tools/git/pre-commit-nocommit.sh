#!/usr/bin/env bash

#
# To prevent debug code from being accidentally committed, simply add a comment near your
# debug code containing the keyword NOCOMMIT and this script will abort the commit.
#
if git commit -v --dry-run | grep 'NOCOMMIT' >/dev/null 2>&1; then
    echo "Trying to commit non-committable code."
    echo "Remove the NOCOMMIT string and try again."
    exit 1
else
    # Run local pre-commit hook if exists
    if [ -e ./.git/hooks/pre-commit ]; then
        ./.git/hooks/pre-commit "$@"
    else
        exit 0
    fi
fi
