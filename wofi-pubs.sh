#!/usr/bin/env bash
#
# Search through your pubs database and open file
#
# Author: Cristóbal Tapia Camú
#
# Needs FontAwesome
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

source ${HOME}/.config/wofi-pubs/config

function list_publications() {
    printf " <b>Change library</b>|"
    printf " <b>Add publication</b>|"
    printf " <b>Search tags</b>|"
    printf " <b>Sync. repo</b>|"
    local lib_conf=$1
	${PUBS} -c ${lib_conf} list | (awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            if (match($0, /(^[^"]*)/, m)); author=m[0];
            if (match($0, /(".+")/, m)); title=m[0];
            if (match($0, /(\([0-9]+\))/, m)); year=m[0];
            if (/\[pdf\]/){
                printf "%-2s <b>%s</b> %s <tt><b>%s</b></tt>\n      <i>%s</i>|", "", author, year, key, title
            }
            else
                printf "%-2s <b>%s</b> %s <tt><b>%s</b></tt>\n      <i>%s</i>|", "", author, year, key, title
        }')
}

# List publications filtered by tag
# $1 : library
# $2 : tag
function list_pubs_tags() {
    printf " <b>Change library</b>|"
    printf " <b>Search tags</b>|"
    printf " <b>Back</b>|"
    local lib_conf=$1
    local tag=$2
	${PUBS} -c ${lib_conf} list "tags:${tag}" | (awk \
        '{
            gsub(/&/, "&amp;");
            key=$1; $1="";
            if (match($0, /(^[^"]*)/, m)); author=m[0];
            if (match($0, /(".+")/, m)); title=m[0];
            if (match($0, /(\([0-9]+\))/, m)); year=m[0];
            if (/\[pdf\]/){
                printf "%-2s <b>%s</b> %s <tt><b>%s</b></tt>\n      <i>%s</i>|", "", author, year, key, title
            }
            else
                printf "%-2s <b>%s</b> %s <tt><b>%s</b></tt>\n      <i>%s</i>|", "", author, year, key, title
        }')
}

function main_fun() {
    prompt='search for publication...'
    local lib_conf=$1

    SELECTION=$(list_publications ${lib_conf} | ${WOFI} \
        --insensitive \
        --allow-markup \
        --width 1200 \
        --height 550 \
        --prompt="${prompt}" \
        --dmenu \
        --define dmenu-separator='|' \
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
            # Extract citation key
            bibkey=$(echo ${SELECTION} | sed 's/.*\[\([^]]*\)\].*/\1/g')
            # Store bibkey of the selected reference
            menu_ref ${bibkey} ${lib_conf};;
    esac

}


# Menu to display actions and information of selected reference
# $1 : bibkey
# $2 : library
# $3 : iformation shown in wofi in case the menu is re-called after
#      some action within the same reference
function menu_ref() {
    IFS=$'\n'
    # Analyze bibfile information
    local bibkey=$1
    local lib_conf=$2

    # If the information to be shown in the wofi-menu has not been supplied,
    # then we create the information, otherwise use the previously generated
    # data (improves speed)
    if [[ -z $3 ]]; then
        declare -a bibinfo=$(${PUBS} -c ${lib_conf} export ${bibkey} | ${BIB_PARSE} --all)

        declare -a tags=$(${PUBS} -c ${lib_conf} tag ${bibkey} | awk '{gsub(" ", "; "); print $0}')
        # Second menu
        declare -a entries=( \
            " <b>Open</b>|" \
            " <b>Export</b>|" \
            " <b>Send to DPT-RP1</b>|" \
            " <b>From same author(s)</b>|" \
            " <b>Edit</b>|" \
            " <b>Back</b>|" \
            " <b>More actions</b>|" \
            " |" \
            "${bibinfo}" \
            " <tt><b>Tags:      </b></tt> ${tags}" )
    else
        entries=$3
    fi


    selected=$(printf '%s' "${entries[@]}" | \
        ${WOFI} -i \
        --width 800 \
        --height 330 \
        --prompt 'Action...' \
        --dmenu \
        --define dmenu-separator='|' \
        --cache-file /dev/null | sed -e 's/<[^>]*>//g')

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
          ${PUBS} -c ${lib_conf} export ${bibkey} | wl-copy
          menu_ref ${bibkey} ${lib_conf} ${entries};;
      'open')
          ${PUBS} -c ${lib_conf} doc open --with ${PDFVIEWER} ${bibkey}
          ;;
      'edit')
          ${TERMINAL_EDIT} ${TERMINAL_ARGS} "Pubs edit" \
                -e "${PUBS} -c ${lib_conf} edit ${bibkey}"
          menu_ref ${bibkey} ${lib_conf} ${entries}
          ;;
      'send to dpt-rp1')
          menu_send_to_dpt ${bibkey} ${lib_conf};;
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
        " Send E-mail" \
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
      'send e-mail')
          send_mail ${bibkey} ${lib_conf};;
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
            ${TERMINAL_EDIT} ${TERMINAL_ARGS} "Pubs edit" \
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
        --define dmenu-separator='|' \
        --dmenu \
        --cache-file /dev/null | sed -e 's/<[^>]*>//g')

    # Exit script if no selection is made
    case ${SELECTION} in
        "" )
            exit 1;;
        " Change library" )
            menu_change_lib;;
        " Search tags" )
            menu_search_tags ${lib_conf};;
        " Back" )
            main_fun ${lib_conf};;
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

# Menu to select DPT device
# $1 : cite-key
# $2 : library
function menu_send_to_dpt() {
    local addr=$(cat ~/.dpapp/devices | \
        ${WOFI} -i \
        --width 600 \
        --height 100 \
        --prompt 'Select device...' \
        --dmenu \
        --cache-file /dev/null | awk \
        ' { print $2 } '
    )

    send_to_dpt $1 $2 $addr

}

# Copy document to the DPT-RP1 (requires the python library
# 'dptrp1'
# $1 : cite-key
# $2 : library
# $3 : DPT-address
function send_to_dpt() {
    ${PUBS_TO_DPT} --library $2 --addr $3 send $1
    notify_add "Document [$1] sent to DPT-RP1!" ""
    menu_ref $1 $2
}

# Send reference and document per E-mail
# $1 : cite-key
# $2 : library
function send_mail() {
    ~/.local/bin/pubs-utils --library $2 mail $1
}

# Call the main function
main_fun $DEFAULT_LIB
