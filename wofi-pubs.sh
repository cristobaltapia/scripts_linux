#!/usr/bin/env bash
# Search through your pubs database and open file
# Needs FontAwesome

PDFVIEWER=zathura
WOFI=wofi
PUBS=pubs
CONFIGS_DIR=~/.config/pubs
DEFAULT_LIB=~/.config/pubs/main_library.conf
CACHE=~/.local/tmp/pubs_wofi
CACHE_AUTH=~/.local/tmp/pubs_wofi_auth
CACHE_LIBS=~/.local/tmp/pubs_wofi_libs
TERMINAL_EDIT=termite
BIB_PARSE=~/.local/bin/parse-bib-file
PUBS_TO_DPT=~/.local/bin/pubs_to_dptrp1

function list_publications() {
    echo " <b>Change library</b>"
    echo " <b>Add publication</b>"
    echo " <b>Search tags</b>"
    echo " <b>Sync. repo</b>"
    local lib_conf=$1
	${PUBS} -c ${lib_conf} list | (awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            authors=gensub(/(^[^"]*)/, "<b>\\1</b>", 1, $0);
            title=gensub(/(".+")/, "– <i>\\1</i>", 1, authors);
            info=gensub(/([^>]+$)/, "", 1, title);
            if (/\[pdf\]/){
                printf "%-2s<tt><b>%-18s</b></tt>  %s\n", "", key, info
            }
            else
                printf "%-2s<tt><b>%-18s</b></tt>  %s\n", "", key, info
        }')
}

# List publications filtered by tag
# $1 : library
# $2 : tag
function list_pubs_tags() {
    echo " <b>Change library</b>"
    echo " <b>Add publication</b>"
    echo " <b>Search tags</b>"
    echo " <b>Sync. repo</b>"
    local lib_conf=$1
    local tag=$2
	${PUBS} -c ${lib_conf} list "tags:${tag}" | (awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            authors=gensub(/(^[^"]*)/, "<b>\\1</b>", 1, $0);
            title=gensub(/(".+")/, "– <i>\\1</i>", 1, authors);
            info=gensub(/([^>]+$)/, "", 1, title);
            if (/\[pdf\]/){
                printf "%-2s<tt><b>%-18s</b></tt>  %s\n", "", key, info
            }
            else
                printf "%-2s<tt><b>%-18s</b></tt>  %s\n", "", key, info
        }')
}

function main_fun() {
    prompt='search for publication...'
    local lib_conf=$1

    SELECTION=$(list_publications ${lib_conf} | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 1200 \
        --height 450 \
        --prompt="${prompt}" \
        --dmenu \
        --cache-file /dev/null | sed -e 's/<[^>]*>//g')

    # Exit script if no selection is made
    case ${SELECTION} in
        "" )
            exit 1;;
        " Add publication" )
            menu_add ${lib_conf};;
        " Change library" )
            menu_change_lib;;
        " Search tags" )
            menu_search_tags ${lib_conf};;
        * )
            bibkey=$(echo ${SELECTION} | awk \
                '{sub(/\[/, " "); sub(/\]/, " "); printf $2}')
            # Store bibkey of the selected reference
            menu_ref ${bibkey} ${lib_conf};;
    esac

}


# Menu to display actions and information of selected reference
# $1 : bibkey
# $2 : library
function menu_ref() {
    IFS=$'\n'
    # Analyze bibfile information
    local bibkey=$1
    local lib_conf=$2

    declare -a bibinfo=$(${PUBS} -c ${lib_conf} export ${bibkey} | ${BIB_PARSE} --all)

    declare -a tags=$(${PUBS} -c ${lib_conf} tag ${bibkey} | awk '{gsub(" ", "; "); print $0}')

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
        ${bibinfo[@]} \
        " <tt><b>Tags:      </b></tt> ${tags}" )

    selected=$(printf '%s\n' "${entries[@]}" | \
        ${WOFI} -i \
        --width 800 \
        --height 330 \
        --prompt 'Action...' \
        --dmenu \
        --cache-file /dev/null)

    selected=$(echo ${selected} | awk \
        '{
        $1="";
        gsub(/^[ \t]+/, "", $0);
        $0=tolower($0);
        printf "%s", $0
        }')

    case $selected in
      '')
          exit 1;;
      'export')
        ${PUBS} -c ${lib_conf} export ${bibkey} | wl-copy;;
      'open')
        ${PUBS} -c ${lib_conf} doc open --with ${PDFVIEWER} ${bibkey};;
      'edit')
          ${TERMINAL_EDIT} -t "Pubs edit" \
              -e "${PUBS} -c ${lib_conf} edit ${bibkey}"
          menu_ref ${bibkey} ${lib_conf}
                        ;;
      'send to dpt-rp1')
          send_to_dpt ${bibkey} ${lib_conf};;
      'from same author(s)')
          menu_same_authors ${bibkey} ${lib_conf};;
      'more actions')
          menu_more_actions ${bibkey} ${lib_conf};;
      'back')
          main_fun ${lib_conf};;
    esac
}

# Menu with more actions for a citation
# $1 : citekey
# $2 : library
function menu_more_actions() {
    IFS=$'\n'
    # Analyze bibfile information
    local bibkey=$1
    local lib_conf=$2

    declare -a bibinfo=$(${PUBS} -c ${lib_conf} export ${bibkey} | ${BIB_PARSE} --all)

    # Second menu
    declare -a entries=( \
        " Add document" \
        " Add tag" \
        " Back" )

    selected=$(printf '%s\n' "${entries[@]}" | \
        ${WOFI} -i \
        --width 800 \
        --height 330 \
        --prompt 'Action...' \
        --dmenu \
        --cache-file /dev/null)

    selected=$(echo ${selected} | awk \
        '{
        $1="";
        gsub(/^[ \t]+/, "", $0);
        $0=tolower($0);
        printf "%s", $0
        }')

    case $selected in
      'add document')
          add_doc ${bibkey} ${lib_conf};;
      'add tag')
          add_tag ${bibkey} ${lib_conf};;
      'back')
          menu_ref ${bibkey} ${lib_conf};;
    esac
}

# Function to add a new document to the library
function menu_add() {
    local lib_conf=$1
    # Options
    declare -a entries=( \
        " DOI" \
        " arXiv" \
        " ISBN" \
        " Bibfile" \
        " Manual Bibfile" \
        " Back")

    selected=$(printf '%s\n' "${entries[@]}" | \
        ${WOFI} -i \
        --width 800 \
        --height 300 \
        --prompt 'From...' \
        --dmenu \
        --cache-file /dev/null | awk \
            '{
                $1="";
                gsub(/^[ \t]+/, "", $0);
                $0=tolower($0);
                printf "%s", $0
            }')

    case $selected in
        # Import from DOI
        "doi" )
            DOI=$(zenity --entry --text="DOI to import:")
            OUT=$($PUBS -c $lib_conf add --doi ${DOI} 2> ~/.local/tmp/tmp_pubs)
            ERROR=$(<~/.local/tmp/tmp_pubs)

            notify_add "${OUT}" "${ERROR}"

            # Get assigned citation key
            bibkey=$(echo "${OUT}" | awk -F "[][]" '{ print $2 }')
            # Add doc
            add_doc $bibkey $lib_conf
            ;;

        # Import from ISBN
        "isbn" )
            ISBN=$(zenity --entry --text="ISBN to import:")
            # Capture stdout and stderr
            OUT=$($PUBS -c $lib_conf add --isbn ${ISBN} 2> ~/.local/tmp/tmp_pubs)
            ERROR=$(<~/.local/tmp/tmp_pubs)

            notify_add"${OUT}" "${ERROR}"

            # Get assigned citation key
            bibkey=$(echo "${OUT}" | awk -F "[][]" '{ print $2 }')
            # Add doc
            add_doc $bibkey $lib_conf

            ;;

        # Import from arXiv
        "arxiv" )
            ARXIV=$(zenity --entry --text="arXiv to import:")
            OUT=$($PUBS -c $lib_conf add --arxiv ${ARXIV} 2> ~/.local/tmp/tmp_pubs)
            ERROR=$(<~/.local/tmp/tmp_pubs)

            notify_add"${OUT}" "${ERROR}"

            # Get assigned citation key
            bibkey=$(echo "${OUT}" | awk -F "[][]" '{ print $2 }')
            # Add doc
            add_doc $bibkey $lib_conf

            ;;

        # Import from bibfile
        "bibfile" )
            BIBFILE=$(zenity --file-selection --file-filter=*.bib --text="Bibfile to import:")
            OUT=$($PUBS -c $lib_conf add ${BIBFILE} 2> ~/.local/tmp/tmp_pubs)
            ERROR=$(<~/.local/tmp/tmp_pubs)

            notify_add"${OUT}" "${ERROR}"

            # Get assigned citation key
            bibkey=$(echo "${OUT}" | awk -F "[][]" '{ print $2 }')
            # Add doc
            add_doc $bibkey $lib_conf

            ;;

        # Manual entry
        "manual bibfile" )
            TMPBIBFILE=~/.local/tmp/bibfile_tmp.bib
            ${TERMINAL_EDIT} -t "Pubs edit" \
                  -e "nvim ${TMPBIBFILE}"
            OUT=$($PUBS -c $lib_conf add ${TMPBIBFILE} 2> ~/.local/tmp/tmp_pubs)

            ERROR=$(<~/.local/tmp/tmp_pubs)

            notify_add"${OUT}" "${ERROR}"

            # Get assigned citation key
            bibkey=$(echo "${OUT}" | awk -F "[][]" '{ print $2 }')
            # Add doc
            add_doc $bibkey $lib_conf

            rm ${TMPBIBFILE}

            ;;
        "back")
            main_fun ${lib_conf};;

        "*" )
    esac

}

function menu_change_lib() {
    # List libraries from the specified folder
    selected=$(ls -1 ${CONFIGS_DIR} | \
        awk '{ gsub(".*/", ""); printf "%s\n", $0 }' | \
        ${WOFI} -i \
        --width 400 \
        --height 300 \
        --prompt 'Choose library...' \
        --dmenu \
        --cache-file /dev/null \
    )

    local lib_selected="${CONFIGS_DIR}/${selected}"
    # Call the main function with the selected library as parameter
    main_fun $lib_selected
}


# Search tags
# $1 : library
function menu_search_tags() {
    local lib_conf=$1

    # FIXME: tag separation
    local tags=$($PUBS -c ${lib_conf} tag | awk '{gsub(" ", "\n"); print $0}')

    # List tags from the specified library
    selected=$(printf '%s\n' "${tags[@]}" | \
        ${WOFI} -i \
        --width 400 \
        --height 300 \
        --prompt 'Search tags...' \
        --dmenu \
        --cache-file /dev/null \
    )

    # Use selected tag to filter citations
    prompt='search for publication...'

    SELECTION=$(list_pubs_tags ${lib_conf} ${selected} | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 1200 \
        --height 450 \
        --prompt="${prompt}" \
        --dmenu \
        --cache-file /dev/null | sed -e 's/<[^>]*>//g')

    # Exit script if no selection is made
    case ${SELECTION} in
        "" )
            exit 1;;
        " Add publication" )
            menu_add ${lib_conf};;
        " Change library" )
            menu_change_lib;;
        " Search tags" )
            menu_search_tags ${lib_conf};;
        * )
            bibkey=$(echo ${SELECTION} | awk \
                '{sub(/\[/, " "); sub(/\]/, " "); printf $2}')
            # Store bibkey of the selected reference
            menu_ref ${bibkey} ${lib_conf};;
    esac
}

# Notification
# $1 : stdout
# $2 : stderr
function notify_add() {
    if [[ -n $2 ]]; then
        display_error "$2"
        exit 1
    else
        # Get assigned citation key
        bibkey=$(echo "${1}" | awk -F "[][]" '{ print $2 }')
        display_successful_add $bibkey "$1"
    fi
}

# When the addition of a citation fails, this function is called to notify
# the user about it
function display_error() {
    #function_body
    notify-send -a "Pubs" \
        -u normal \
        -t 10 \
        "Pubs Error" \
        "$1"
}

# Send a notification to the user when the addition of the citation was
# successfull
function display_successful_add() {
    #function_body
    notify-send -a "Pubs" \
        -u normal \
        -t 10 \
        "Pubs: $1" \
        "$2"
}


# Add document to citation
# $1 : cite-key
# $2 : library
function add_doc() {
    local DOCFILE=$( zenity --file-selection --file-filter="*.pdf" )

    $PUBS -c $2 doc add "${DOCFILE}" $1
}


# Add tag to citation
# $1 : cite-key
# $2 : library
function add_tag() {
    local bibkey=$1
    local lib_conf=$2

    # Get tags
    # TODO: mark tags already belonging to citation
    local tags=$($PUBS -c ${lib_conf} tag | awk '{gsub(" ", "\n"); print $0 }')
    # TODO: report bug in pubs regarding printing of tags
    local SELECTMODE=1
    declare -a selection=""

    # Add tags until no new tag is given
    while [[ $SELECTMODE ]]; do
        selected=$(printf "${tags}" | \
            ${WOFI} -i \
            --width 800 \
            --height 330 \
            --prompt 'Add a tag...' \
            --exec-search \
            --dmenu \
            --cache-file /dev/null)

        if [[ $selected == "" ]]; then
            break
        fi

        $PUBS -c $lib_conf tag $bibkey "${selected}"
    done

    # return to citation menu
    menu_ref ${bibkey} ${lib_conf}
}

# Copy document to the DPT-RP1 (requires the python library
# 'dptrp1'
# $1 : cite-key
# $2 : library
function send_to_dpt() {
    ${PUBS_TO_DPT} --library $2 send $1
    notify_add "Document [$1] sent to DPT-RP1!" ""
}

# Call the main function
main_fun $DEFAULT_LIB
