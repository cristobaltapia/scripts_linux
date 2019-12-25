#!/usr/bin/env bash
# Search through your pubs database and open file

PDFVIEWER=zathura
WOFI=wofi
PUBS=pubs
CACHE=~/.local/tmp/pubs_wofi

function list_publications() {
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

function main_fun() {
    prompt='search for publication...'
    PUBKEY=$(list_publications | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 1200 \
        --height 450 \
        --prompt="${prompt}" \
        --dmenu \
        --cache-file ${CACHE})

    # Store bibkey of the selected reference
    bibkey=$(echo ${PUBKEY} | awk '{sub(/\[/, " "); sub(/\]/, " "); printf $2}')

    # Exit script if no selection is made
    if [[ ${bibkey} == "" ]]; then
        exit 1
    fi

    menu_ref ${bibkey}

}

function menu_ref() {
    IFS=$'\n'
    # Analyze bibfile information
    bibkey=$1
    declare -a bibinfo=$(${PUBS} export ${bibkey} | ~/.local/bin/parse-bib-file)

    # Second menu
    declare -a entries=(" Open" " Export" " Send to DPT-RP1" " Back" "  " ${bibinfo[@]})

    selected=$(printf '%s\n' "${entries[@]}" | ${WOFI} -i --width 800 --height 220 --prompt 'Action...' --dmenu --cache-file /dev/null)

    # Exit script if no selection is made
    if [[ ${selected} == "" ]]; then
        exit 1
    fi

    selected=$(echo ${selected} | awk \
        '{
        $1="";
        gsub(/^[ \t]+/, "", $0);
        $0=tolower($0);
        printf "%s", $0
        }')

    case $selected in
      export)
        ${PUBS} export ${bibkey} | wl-copy;;
      open)
        ${PUBS} doc open --with ${PDFVIEWER} ${bibkey};;
      back)
        main_fun;;
    esac
}

# Call the main function
main_fun
