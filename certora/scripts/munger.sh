#!/bin/bash
set -e -o pipefail

echo "Mungering $1"
MUNGER_DIR="certora/munger"
mkdir -p "$MUNGER_DIR"

# Put all the sources into a single file
forge flatten "src/$1" |
    # Glue all lines together so sed can handle multi-line patterns
    tr '\n' '\v' |
    # Make each library and contract a separate line
    sed 's/\v\(\(abstract \)\?contract\|library\|interface\)\b/\n\1/g' |
    # Make each contract function definition a separate line
    sed '/^\(abstract \)\?contract\b/s/\v\( *function\b[^{;]*[^\v]*\)\v/\n\1\n/g' |

    # Make everything private internal
    sed 's/\bprivate\b/internal/g' |
    # Make everything internal public except library entries, interface entries
    # and functions dealing with storage in their APIs
    sed '/^\(library\|interface\| *function\b.*\bstorage\)\b/!s/\binternal\b/public/g' |

    # Make all virtual functions non-virtual
    sed 's/\bvirtual\b//g' |
    # Make every contract function virtual
    sed '/^ *function\b/s/\b\(external\|public\|internal\)\b/\0 virtual/g' |

    # Restore the original line breaks
    tr '\v' '\n' \
    > "$MUNGER_DIR/$1"
