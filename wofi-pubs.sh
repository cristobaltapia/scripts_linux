#!/usr/bin/env bash
# Search through your pubs database and open file

PDFVIEWER=zathura
WOFI=wofi
PUBS=pubs
CACHE=~/.local/tmp/pubs_wofi
CACHE_AUTH=~/.local/tmp/pubs_wofi_auth
CACHE_LIBS=~/.local/tmp/pubs_wofi_libs
TERMINAL_EDIT=termite

function list_publications() {
    echo " <b>Change library</b>"
    echo " <b>Add publication</b>"
    echo " <b>Sync. repo</b>"
	${PUBS} list | (awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            authors=gensub(/(^[^\"]*)/, "<b>\\1</b>", 1, $0);
            title=gensub(/(\".+\")/, "– <i>\\1</i>", 1, authors);
            info=gensub(/([^>]+$)/, "", 1, title);
            if (/\[pdf\]/){
                printf "<tt>%-2s<b>%-18s</b></tt>  %s\n", "", key, info
            }
            else
                printf "<tt>%-2s<b>%-18s</b></tt>  %s\n", "", key, info
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

    rm ${CACHE}

    # Store bibkey of the selected reference
    bibkey=$(echo ${PUBKEY} | awk '{sub(/\[/, " "); sub(/\]/, " "); printf $3}')

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

# Menu to display actions and information of selected reference
# $1 : bibkey
# $2 : library
function menu_ref() {
    IFS=$'\n'
    # Analyze bibfile information
    bibkey=$1

    declare -a bibinfo=$(${PUBS} export ${bibkey} | ~/.local/bin/parse-bib-file --all)

    # Second menu
    declare -a entries=( \
        " Open" \
        " Export" \
        " Send to DPT-RP1" \
        " From same author(s)" \
        " Edit" \
        " Back" \
        " More actions" \
        "  " \
        ${bibinfo[@]})

    selected=$(printf '%s\n' "${entries[@]}" | \
        ${WOFI} -i \
        --width 800 \
        --height 300 \
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
        ${PUBS} export ${bibkey} | wl-copy;;
      'open')
        ${PUBS} doc open --with ${PDFVIEWER} ${bibkey};;
      'edit')
          ${TERMINAL_EDIT} -t "Papis edit" \
              --exec="${PUBS} edit ${bibkey}";;
      'from same author(s)')
          menu_same_authors ${bibkey} ${library};;
      'back')
          main_fun ${library};;
    esac
}


# Call the main function
main_fun
