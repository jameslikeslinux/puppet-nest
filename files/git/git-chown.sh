#!/bin/bash

case $# in
    2)
        ownership="$1"
        dir="$2"
        ;;

    1)
        ownership="$1"
        dir='.'
        ;;

    *)
        echo "Usage: ${0} OWNER[:GROUP] [DIR]" >&2
        exit 1
        ;;
esac

if [[ ! -d "${dir}/.git" ]]; then
    echo "${dir} is not a git repository" >&2
    exit 2
fi

cd "$dir"

chown -R "$ownership" .git && git ls-files | while read file; do
    dirname "$file"
    echo "$file"
done | sort -u | xargs chown "$ownership" 2>&1 | tee /tmp/chown.txt
