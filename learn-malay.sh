#!/bin/bash

: "${GEMINI_CONFIGS:="/usr/local/etc/let-s-learn-malay/gemini.conf"}"
: "${LAST_RESPONSE_FILE:="/usr/local/etc/let-s-learn-malay/response.json"}"
: "${LEARNING_STATE_FILE:="/usr/local/etc/let-s-learn-malay/data.state"}"
: "${WORD_LIST_FILE:="/usr/local/etc/let-s-learn-malay/word-list.csv"}"

TERMINAL_LENGTH="$(tput cols || echo 130)"
declare INTERNET

# checks if the given file exist
# ARGS: filename
file_exists() {

    if [[ -f "${1}" ]]; then

        return 0
    fi

    return 1
}

# Disply all the retrieved data
# ARGS: RESPONSE
display_data() {

    declare R1C # Row 1, Column
    declare R1  # Row 1
    declare R2C # Row 2 Column
    declare R2  # Row 2
    declare R3  # Row 3
    local WELCOME_BANNER_PID

    welcome_banner() {
        local TEXT="😊 \033[0;1;38;5;077mLet's Learn Malay\033[0m 💪"
        local HALF_LEN=$(((TERMINAL_LENGTH - 27) / 2))

        echo -en "\033[0;38;5;098m"

        for _ in $(seq 1 ${HALF_LEN}); do
            echo -n "─"
        done

        echo -n "  "
        echo -en "${TEXT}"
        echo -en "  \033[0;35m"

        for _ in $(seq 1 $((HALF_LEN - 1))); do
            echo -n "─"
        done

        echo "─"

        return 0

    }

    welcome_banner &
    WELCOME_BANNER_PID=$!

    # first row
    first_row() {
        local len
        local tmp

        tmp="${3}"

        len=$((55 - ("${#1}" + "${#2}" + "${#3}")))

        for i in $(seq 1 "${len}"); do
            tmp+=" "
        done

        echo -en "\033[0;38;5;131;1m🟆 \033[0;4;38;5;179;1m${1}\033[0;38;5;098;1m ─ \033[0;38;5;145m'${2}'\033[0;1;38;5;098m ─ \033[0;1;38;5;185m${tmp}"
    }

    # second & third rows
    second_n_third_rows() {

        local len
        local tmp

        tmp="${2}"

        len=$((57 - ("${#1}" + "${#2}")))

        for i in $(seq 1 "${len}"); do
            tmp+=" "
        done

        echo -en "\033[0;38;5;131;1m  ${3}. \033[0;1;38;5;114m${1}\033[0;38;5;098;1m ─ \033[0;38;5;080m${tmp}"
    }

    for i in {0..2}; do

        R1C[0]="$(jq -r ".words[${i}].MALAY_WORD" <<<"${1}")"
        R1C[1]="$(jq -r ".words[${i}].PRONUNCIATION" <<<"${1}")"
        R1C[2]="$(jq -r ".words[${i}].DEFINITION" <<<"${1}")"

        R1[i]="$(first_row "${R1C[0]}" "${R1C[1]}" "${R1C[2]}")"

        for j in {0..1}; do

            R2C[0]="$(jq -r ".words[${i}].EXAMPLES[${j}]" <<<"${1}")"
            R2C[1]="$(jq -r ".words[${i}].EXAMPLE_MEANINGS[${j}]" <<<"${1}")"

            if [ "${j}" -eq 0 ]; then

                R2[i]="$(second_n_third_rows "${R2C[0]}" "${R2C[1]}" "1")"

                continue

            fi

            R3[i]="$(second_n_third_rows "${R2C[0]}" "${R2C[1]}" "2")"

        done

    done

    wait "${WELCOME_BANNER_PID}"

    # Print on a single row
    if [ "${TERMINAL_LENGTH}" -gt 195 ]; then

        echo "${R1[0]}${R1[1]}${R1[2]}"
        echo "${R2[0]}${R2[1]}${R2[2]}"
        echo "${R3[0]}${R3[1]}${R3[2]}"

    # Print with two rows
    elif [ "${TERMINAL_LENGTH}" -gt 130 ]; then

        echo "${R1[0]}${R1[1]}"
        echo "${R2[0]}${R2[1]}"
        echo -e "${R3[0]}${R3[1]}\n"

        echo "${R1[2]}"
        echo "${R2[2]}"
        echo "${R3[2]}"

    # print with three rows
    else

        echo "${R1[0]}"
        echo "${R2[0]}"
        echo -e "${R3[0]}\n"

        echo "${R1[1]}"
        echo "${R2[1]}"
        echo -e "${R3[1]}\n"

        echo "${R1[2]}"
        echo "${R2[2]}"
        echo "${R3[2]}"

    fi

    # footer
    for _ in $(seq 1 "${TERMINAL_LENGTH}"); do

        echo -en "\033[0;35m─"

    done

}

# validate if the parsed string
# ARGS: string to verify
valid_json() {

    if [[ $(echo "${1}" | jq -r keys[0]) == "error" ]]; then
        return 1
    fi
    if [[ $(echo "${1}" | jq -r keys[0]) == "words" ]]; then
        return 0
    fi
    # echo "${1}" | jq -e '.words'

    # if echo "${1}" | jq -e '.words' >/dev/null 2>&1; then
    # verbose "Valid_json() : 0 - Correct format"
    # return 0
    # else
    # verbose "Valid_json() : 1 - Incorrect format"
    # return 1
    # fi

    # jq empty <<<"${1}" >/dev/null 2>&1

    return $?

}

# ARGS: prompt
fetch_new_data() {

    local CHANCES
    local PAYLOAD
    local API_KEY
    local PROMPT
    local RESPONSE

    PROMPT="${1}"

    # Check whether the computer has an active internet connection
    while ! internet; do

        sleep $(("${CHANCES}" * 60))

        if [[ "${CHANCES}" -le 5 ]]; then
            continue
        fi

        ((CHANCES += 1))

    done

    # Gemini Configs file does not exist
    if ! file_exists "${GEMINI_CONFIGS}"; then

        echo "Error: Gemini config file does not exist!" >&2
        echo "       To use Gemini-Ai API need the API key." >&2
        echo "       Enter your API key at ${GEMINI_CONFIGS}" >&2

        # last response file exist
        if file_exists "${LAST_RESPONSE_FILE}"; then

            LAST_RESPONSE="$(<"${LAST_RESPONSE_FILE}")"

            # the response is valid
            if valid_json "${LAST_RESPONSE}"; then

                echo "Showing the last response" >&2

                display_data "${LAST_RESPONSE}"

                return 0

            fi
            # The response isn't valid

            echo "Last response file isn't valid" >&2

            exit 1

        fi

        echo "Couldn't find the last response file" >&2

        exit 1

    fi
    # found Gemini config file

    source "${GEMINI_CONFIGS}"

    PAYLOAD=$(
        cat <<EOF
        {"contents":[{"role":"user","parts":[{"text":"${PROMPT}"}]}],
            "systemInstruction":{
            "role":"user",
            "parts":[{
                    "text": "You are a language learning assistant.\n\nYour core function is to help learn the language Malay (Bahasa Malaysia) words To speak Malay language fluently and natively\n\nHere are instructions to operate:\n\n1. Daily Word Delivery:\n\n- If the user prompts you with: \"Help me learn Malay [word1], [word2], [word3]\", and provides three Malay words, your task is to return the pronunciation, definition, and example sentences for each word.\n  OR\n- If the user prompts you with: \"Day [Number]\", you should choose 3 unique words according to the day number. Avoid repeating words from previous days.\n\n2. **Word Format:**\n\n- For each word, provide the following details in the format below:\n\n  - Malay Word: [Word in Malay]\n  - Pronunciation: [Approximate pronunciation guide for English speakers]\n  - Definition: [Meaning of the word in English]\n  - Example: [simple Malay sentence using the word, along with its English translation]\n\n- The output format: {\"words\":[{\"MALAY_WORD\":\"malay word\",\"PRONUNCIATION\":\"pronunciation\",\"DEFINITION\":\"definition\",\"EXAMPLES\":[\"Noun example\", \"Verb example\"],\"EXAMPLE_MEANINGS\":[\"Noun example meaning\",\"Verb example meaning\"]}]}\n\n3. **Response Example:**\n\n- If the user prompts \"Help me learn Malay buku, meja, kerusi\", Your response should look like this:\n  \"{\"words\":[{\"MALAY_WORD\":\"buku\",\"PRONUNCIATION\":\"boo-koo\",\"DEFINITION\":\"book\",\"EXAMPLES\":[ \"Saya membaca buku.\",\"Buku ini sangat menarik.\"],\"EXAMPLE_MEANINGS\":[\"I am reading a book.\",\"This book is very interesting.\"]},{\"MALAY_WORD\":\"meja\",\"PRONUNCIATION\":\"meh-jah\",\"DEFINITION\":\"table\",\"EXAMPLES\":[\"Meja ini besar.\",\"Saya letakkan buku di atas meja.\"],\"EXAMPLE_MEANINGS\":[\"This table is big.\",\"I placed the book on the table.\"]},{\"MALAY_WORD\":\"kerusi\",\"PRONUNCIATION\":kuh-roo-see\",\"DEFINITION\":\"chair\",\"EXAMPLES\":[\"Kerusi itu sangat selesa.\",\"Saya duduk di atas kerusi.\"],\"EXAMPLE_MEANINGS\":[\"That chair is very comfortable.\",\"I am sitting on the chair.\"]}]}\"\n\n4. **Task Execution:**\n\n- Do not encapsulate the JSON in markdown\n- The chatbot should only provide the response in the specified format.\n- Focus on clear and concise responses, ensuring practical usage.\n- If the word is ambiguous or not sure respond with a similar word\n- Use emojis where suitable and possible to enhance engagement.\n- Apply capitalization as appropriate"
                }]},
            "generationConfig":{
            "temperature":0.7,
            "topK":55,
            "topP":0.9,
            "maxOutputTokens":8192,
            "responseMimeType":"text/plain"
            }}
EOF
    )

    API_KEY=$(base64 --decode <<<"${GEMINI_API_KEY}")

    CHANCES=0

    for _ in {0..3}; do

        while ! RESPONSE=$(curl -s \
            -X POST https://generativelanguage.googleapis.com/v1beta/models/"${GEMINI_MODEL}":generateContent?key="${API_KEY}" \
            -H 'Content-Type: application/json' \
            -d "${PAYLOAD}"); do

            if [[ "${CHANCES}" -le 4 ]]; then

                exit 1

            fi

            sleep $((CHANCES * 60))

            ((CHANCES += 1))

            # case "${HTTP_CODE}" in
            # 200)
            #     # somehow the curl has been succeed!
            #     echo "Somehow noticed as an error" >&2
            #     sleep 5
            #     continue
            #     ;;
            # 429)
            #     echo -e "RESOURCE EXHAUSTED \n\tExceeded the rate limit." >&2
            #     sleep 10
            #     continue
            #     ;;
            # 400)
            #     echo -e "INVALID ARGUMENT/FAILED PRECONDITION \n\tThe body is molformed.\n\tfree tier isn't available in your country " >&2
            #     exit 1
            #     ;;
            # 403)
            #     echo -e "PERMISSION DENIED \n\tYour API key doesn't have the required permission" >&2
            #     exit 1
            #     ;;
            # 500)
            #     echo -e "INTERNAL" >&2
            #     sleep 10
            #     continue
            #     ;;
            # *)
            #     echo "for some reason curl failed" >&2
            #     exit 1
            #     ;;
            # esac

            echo "Error RESPONSE failed" >&2

            # break

        done
        # The RESPONSE is correct.

        if [[ $(echo "${RESPONSE}" | jq -r keys[0]) == "error" ]]; then
            sleep 3
            continue
        fi

        RESPONSE="$(echo "${RESPONSE}" | jq -r '.candidates[].content.parts[].text')"

        # RESPONSE is not valid json
        if ! [[ $(echo "${RESPONSE}" | jq -r keys[0]) == "words" ]]; then
            sleep 3
            continue
        fi

        echo "${RESPONSE}" >"${LAST_RESPONSE_FILE}" &
        SAVE_RESPONSE_PID="${!}"

        display_data "${RESPONSE}"
        # display_data "${RESPONSE}" "${SAVE_RESPONSE}"

        wait ${SAVE_RESPONSE_PID}

        return 0
    done

}

# ARGS: day
fetch_prompt() {

    if file_exists "${WORD_LIST_FILE}"; then

        IFS=',' read -r -a WORDS <<<"$(sed "${1:-1}q;d" "${WORD_LIST_FILE}")"

        echo "Help me learn Malay ${WORDS[0]}, ${WORDS[1]}, ${WORDS[2]}"

        return 0

    fi
    # The word list file does not exist

    echo "Day ${1:-1}"

    return 0

}

# output INTERNET=$?
internet() {

    # ping -c 2 -W 5 1.1.1.1 >/dev/null 2>&1
    timeout 5 bash -c "</dev/tcp/1.1.1.1/53"
    INTERNET=$?
    return "${INTERNET}"

}

main() {
    local TODAY
    local DAY_NUMBER

    internet &

    # last accessed date file exist
    if file_exists "${LEARNING_STATE_FILE}"; then

        source "${LEARNING_STATE_FILE}"

        TODAY="$(date --rfc-3339=date)"

        # date == date
        if [ "${TODAY}" == "${LAST_ACCESSED_DATE}" ]; then

            # last response file exist
            if file_exists "${LAST_RESPONSE_FILE}"; then

                LAST_RESPONSE="$(cat "${LAST_RESPONSE_FILE}")"

                # the response isn't valid
                if valid_json "${LAST_RESPONSE}"; then

                    display_data "${LAST_RESPONSE}"

                    return 0

                fi
                # The response isn't valid so fetch new data

                fetch_new_data "$(fetch_prompt $((DAY_NUMBER - 1)))"

                return 0
            fi
            # Last response file isn't exist

            fetch_new_data "$(fetch_prompt $((DAY_NUMBER - 1)))"

            return 0

        fi
        # date != date

        if fetch_new_data "$(fetch_prompt "${DAY_NUMBER}")"; then

            echo -e "LAST_ACCESSED_DATE=${TODAY}\nDAY_NUMBER=$((DAY_NUMBER + 1))" >"${LEARNING_STATE_FILE}"

        fi

        wait

        return 0

    fi
    # last accessed date file does not exists

    DAY_NUMBER=1

    if fetch_new_data "$(fetch_prompt "${DAY_NUMBER}")"; then

        echo -e "LAST_ACCESSED_DATE=${TODAY}\nDAY_NUMBER=$((DAY_NUMBER + 1))" >"${LEARNING_STATE_FILE}" &

    fi

    wait

    return 0

}

main
