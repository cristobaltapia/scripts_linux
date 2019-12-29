#!/usr/bin/env bash
# Search through your papis database and open file
#
# This only works with the option 'database-backend = whoosh'
# of the papis configuration file

PDFVIEWER=zathura
WOFI=wofi
PAPIS=papis
CACHE=~/.local/tmp/papis_wofi
CACHE_AUTH=~/.local/tmp/papis_wofi_auth
CACHE_LIBS=~/.local/tmp/papis_wofi_libs
# The first two fields should not be changed
SHOW_FORMAT='{doc[files]} {doc[ref]} <i>{doc[author]}</i> – <b>"{doc[title]}"</b>'
TERMINAL_EDIT=termite
# Get default library
# DEFAULT_LIB=$(${PAPIS} config default-library)
DEFAULT_LIB=papers

# List all the publications
function list_publications() {
    # If an argument is passed, it is used to change to another existing
    # library
    echo " <b>Change library</b>"
    echo " <b>Add publication</b>"
    echo " <b>Sync. repo</b>"
    local library

    if [[ -z $1 ]]; then
        library=${DEFAULT_LIB}
    else
        library=$1
    fi

    # The publications in the library are listed.
    # Also, we check whether a file is present or not.
    ${PAPIS} \
        --lib ${library} \
        list \
        --all \
        --format "${SHOW_FORMAT}" \
        '*' | \
        awk \
        '{
            gsub(/&/, "&amp;");
            if ($1 ~ /^\[.*\]/) {
                file="";
                $1="";
                key=$2; $2="";
            }
            else {
                file="";
                key=$1;
                $1="";
            }
            printf "<tt><b>%-2s %-18s</b></tt>  %s\n", file, key, $0
        }'
}

# The passed argument '$1' is a query string, e.g.: 'author:Einstein'
function list_publications_auth() {
    local library
    if [[ -z $2 ]]; then
        library=${DEFAULT_LIB}
    else
        library=$2
    fi

	${PAPIS} \
        --lib ${library} \
        list \
        --all \
        --format "${SHOW_FORMAT}" \
        "$1" | \
        awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            printf "<tt><b> %-18s</b></tt>  %s\n", key, $0
        }'
}

# Parse a yaml file
# Function taken from Stefan Farestam (https://stackoverflow.com/a/21189044)
function parse_yaml {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
         -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
         -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
       indent = length($1)/2;
       vname[indent] = $2;
       for (i in vname) {if (i > indent) {delete vname[i]}}
       if (length($3) > 0) {
          vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
          printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
       }
    }'
}

function main_fun() {
    prompt='search for publication...'

    PUBKEY=$(list_publications $1 | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 1200 \
        --height 450 \
        --prompt="${prompt}" \
        --dmenu \
        --cache-file ${CACHE})

    rm ${CACHE}

    # Remove XML tags
    PUBKEY=$(echo ${PUBKEY} | awk '{gsub(/<[^>]*>/, ""); print $0}')

    # Change library
    if [[ ${PUBKEY} == " Change library" ]]; then
        menu_library
        exit 1
    fi

    # Store bibkey of the selected reference
    bibkey=$(echo ${PUBKEY} | awk '{printf $2}')

    # Exit script if no selection is made
    if [[ ${bibkey} == "" ]]; then
        exit 1
    fi

    # The second argument is the library
    menu_ref ${bibkey} $1
}

# Menu to display actions and information of selected reference
# $1 : bibkey
# $2 : library
function menu_ref() {
    IFS=$'\n'
    # Analyze bibfile information
    bibkey=$1

    local library
    if [[ -z $2 ]]; then
        library=${DEFAULT_LIB}
    else
        library=$2
    fi

    eval $(${PAPIS} --lib ${library} export --format yaml "ref:${bibkey}" | parse_yaml)

    declare -a bibinfo=( \
        $(printf " <tt><b>%-11s</b></tt>%s" "Author:" ${author}) \
        $(printf " <tt><b>%-11s</b></tt>%s" "Title:" ${title}) \
        $(printf " <tt><b>%-11s</b></tt>%s" "Year:" ${year}) \
    )

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
          ${PAPIS} --lib ${library} export --format bibtex "ref:${bibkey}" | wl-copy;;
      'open')
          ${PAPIS} --lib ${library} open --tool ${PDFVIEWER} "ref:${bibkey}";;
      'edit')
          ${TERMINAL_EDIT} -t "Papis edit" \
              --exec="${PAPIS} --lib ${library} edit 'ref:${bibkey}'";;
      'from same author(s)')
          menu_same_authors ${bibkey} ${library};;
      'back')
          main_fun ${library};;
    esac
}

# Get references from the same authors as the given reference
# $1 : bibkey
# $2 : library
function menu_same_authors() {
    prompt='Same authors...'
    bibkey=$1

    local library
    if [[ -z $2 ]]; then
        library=${DEFAULT_LIB}
    else
        library=$2
    fi

    query_auth=$(${PAPIS} --lib ${library} export --format bibtex "ref:${bibkey}" | ~/.local/bin/parse-bib-file --author)

    PUBKEY=$(list_publications_auth ${query_auth} ${library} | ${WOFI} \
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

    menu_ref ${bibkey} ${library}
}

function menu_library() {
    prompt='Choose library...'
    # Get libraries
    selected=$(${PAPIS} list --libraries | \
         awk 'BEGIN {FS=" "} {printf "<tt><b>%-16s</b></tt>%s\n", $1, $2}' \
         | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 800 \
        --height 450 \
        --prompt="${prompt}" \
        --dmenu \
        --cache-file ${CACHE_LIBS}
    )

    # Store bibkey of the selected reference
    library=$(echo ${selected} | awk '{gsub(/<[^>]*>/, ""); print $1}')

    # Exit script if no selection is made
    if [[ ${library} == "" ]]; then
        exit 1
    fi

    main_fun ${library}
}

# Call the main function
main_fun
