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

parent_dirs() {
    local file="$1"
    if [[ $file != '.' ]]; then
        local parent="$(dirname "$file")"
        parent_dirs "$parent"
        echo "$parent"
    fi
}

cd "$dir"

chown -R "$ownership" .git && git ls-files | while read file; do
    parent_dirs "$file"
    echo "$file"
done | sort -u | xargs chown -h "$ownership"
