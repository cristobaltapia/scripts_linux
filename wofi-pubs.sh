#!/usr/bin/env bash
# Search through your pubs database and open file

PDFVIEWER=zathura
WOFI=wofi
PUBS=pubs
CACHE=~/.local/tmp/pubs_wofi

list_publications() {
	${PUBS} list | (awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            if (/\[pdf\]/)
                printf "<tt><b>%-18s</b></tt>  %s\n", key" ", $0
            else
                printf "<tt><b>%-18s</b></tt>  %s\n", key, $0
        }')
}

prompt='search for publication...'
PUBKEY=$(list_publications | ${WOFI} -i \
    --allow-markup \
    --width 1200 \
    --height 450 \
    --prompt="${prompt}" \
    --dmenu \
    --cache-file ${CACHE})

# Store bibkey of the selected reference
bibkey=$(echo ${PUBKEY} | awk '{sub(/\[/, " "); sub(/\]/, " "); printf $2}')

echo ${PUBKEY}
echo ${bibkey}
# TODO: Analyze bibfile information

# Second menu
entries="Open\nExport"

selected=$(printf $entries|wofi -i --width 300 --height 150 --dmenu --cache-file /dev/null | awk '{print tolower($1)}')

case $selected in
  export)
    ${PUBS} export ${bibkey} | wl-copy;;
  open)
    ${PUBS} doc open --with ${PDFVIEWER} ${bibkey};;
esac
