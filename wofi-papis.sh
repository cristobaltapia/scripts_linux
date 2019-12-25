#!/usr/bin/env bash
# Search through your papis database and open file

PDFVIEWER=zathura
WOFI=wofi
PAPIS=papis
CACHE=~/.local/tmp/papis_wofi
CACHE_AUTH=~/.local/tmp/papis_wofi_auth

# List all the publications
function list_publications() {
	${PAPIS} \
        list \
        --all \
        --format '{doc[ref]} <i>{doc[author]}</i> - <b>"{doc[title]}"</b>' \
        'ref:*' | \
        awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            printf "<tt><b> %-18s</b></tt>  %s\n", key, $0
        }'
}

function list_publications_auth() {
	${PAPIS} \
        list \
        --all \
        --format '{doc[ref]} <i>{doc[author]}</i> - <b>"{doc[title]}"</b>' \
        "$1" | \
        awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            printf "<tt><b> %-18s</b></tt>  %s\n", key, $0
        }'
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
    declare -a bibinfo=$(${PAPIS} export --format bibtex "ref:${bibkey}" | ~/.local/bin/parse-bib-file --all)

    # Second menu
    declare -a entries=( \
        " Open" \
        " Export" \
        " Send to DPT-RP1" \
        " From same author(s)" \
        " Back" \
        "  " \
        ${bibinfo[@]})

    selected=$(printf '%s\n' "${entries[@]}" | \
        ${WOFI} -i \
        --width 800 \
        --height 250 \
        --prompt 'Action...' \
        --dmenu \
        --cache-file /dev/null)

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
      'export')
          ${PAPIS} export --format bibtex "ref:${bibkey}" | wl-copy;;
      'open')
          ${PAPIS} open --tool ${PDFVIEWER} "ref:${bibkey}";;
      'from same author(s)')
          menu_same_authors ${bibkey};;
      'back')
          main_fun;;
    esac
}

function menu_same_authors() {
    prompt='Same authors...'
    bibkey=$1
    query_auth=$(${PAPIS} export --format bibtex "ref:${bibkey}" | ~/.local/bin/parse-bib-file --author)

    PUBKEY=$(list_publications_auth ${query_auth} | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 1200 \
        --height 450 \
        --prompt="${prompt}" \
        --dmenu \
        --cache-file ${CACHE_AUTH})

    rm ${CACHE_AUTH}

    # Store bibkey of the selected reference
    bibkey=$(echo ${PUBKEY} | awk '{sub(/\[/, " "); sub(/\]/, " "); printf $2}')

    # Exit script if no selection is made
    if [[ ${bibkey} == "" ]]; then
        exit 1
    fi

    menu_ref ${bibkey}

}

# Call the main function
main_fun
