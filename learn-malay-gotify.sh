#!/bin/bash

# : "${GEMINI_CONFIGS:="/usr/local/etc/let-s-learn-malay/gemini.conf"}"
# : "${LAST_RESPONSE_FILE:="/usr/local/etc/let-s-learn-malay/response.json"}"
# : "${LEARNING_STATE_FILE:="/usr/local/etc/let-s-learn-malay/data.state"}"
# : "${WORD_LIST_FILE:="/usr/local/etc/let-s-learn-malay/word-list.csv"}"
# : "${NTFY_CONFIG:="/usr/local/etc/let-s-learn-malay/ntfy.conf"}"
# : "${GOTIFY_CONFIG:="/usr/local/etc/let-s-learn-malay/gotify.conf"}"
: "${LOG_FILE:="${HOME}/let-s-learn-malay.log"}"

#
: "${GEMINI_CONFIGS:="/home/alham/malay/gemini.conf"}"
: "${LAST_RESPONSE_FILE:="/home/alham/malay/response.json"}"
: "${LEARNING_STATE_FILE:="/home/alham/malay/data.state"}"
: "${WORD_LIST_FILE:="/home/alham/malay/word-list.csv"}"
: "${GOTIFY_CONFIG:="/home/alham/malay/gotify.conf"}"
: "${NTFY_CONFIG:="/home/alham/malay/ntfy.conf"}"
#

declare INTERNET=0
LOG_FILE="${HOME}/let-s-learn-malay.log"

# Log error messages to the log file
# ARGS: Error message
log_error() {

    local MESSAGE="${1}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: ${MESSAGE}" >>"${LOG_FILE}"

}

# checks if the given file exist
# ARGS: filename
file_exists() {

    if [[ -f "${1}" ]]; then

        return 0
    fi

    return 1
}

# Send notification to gotify server
# ARGS: title, message
send_notification() {

    local TITLE="${1}"
    local MESSAGE="${2}"
    

    # curl -X POST "${GOTIFY_URL}message" \
    #     -H "Content-Type: application/json" \
    #     -d "{
    #         \"title\": \"${TITLE}\",
    #         \"message\": \"${MESSAGE}\",
    #         \"priority\": 7
    #     }" \
    #     -H "X-Gotify-Key:${GOTIFY_TOKEN}"

    if ! file_exists "${NTFY_CONFIG}"; then

        log_error "Ntfy config file does not exist!"
        exit 1

    fi

    if [[ -r "${NTFY_CONFIG}" ]]; then

        source "${NTFY_CONFIG}"

    else

        log_error "Ntfy config file is not readable or does not exist!"
        exit 1

    fi

    curl \
        -H "Title: ${TITLE}" \
        -d "${MESSAGE}" \
        -H "Priority: ${NTFY_PRIORITY}" \
        -H "Markdown: yes" \
        -H "Authorization: Bearer ${NTFY_TOKEN}" \
        "${NTFY_URL}/${NTFY_TOPIC}"

    return 0
}

# validate if the parsed string
# ARGS: string to verify
valid_json() {

    if [[ $(echo "${1}" | jq -r keys[0]) == "error" ]]; then

        return 1

    fi
    if [[ $(echo "${1}" | jq -r keys[0]) == "word" ]]; then

        return 0

    fi

    return $?

}

# ARGS: prompt
fetch_new_data() {

    local PAYLOAD
    local API_KEY
    local PROMPT
    local RESPONSE

    PROMPT="${1}"

    # Check if the internet is available
    if [[ "${INTERNET}" -ne 0 ]]; then

        log_error "No internet connection available!"

        exit 1

    fi

    # Gemini Configs file does not exist
    if ! file_exists "${GEMINI_CONFIGS}"; then

        log_error "Gemini config file does not exist!"

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
                    "text": "You are a language learning assistant.\n\nYour core function is to help learn the language Malay (Bahasa Malaysia) words To speak Malay language fluently and natively\n\nHere are instructions to operate:\n\n1. Daily Word Delivery:\n\n- If the user prompts you with: \"Help me learn Malay [word]\", and provides a Malay word, your task is to return the definition(English meaning of the word) and example sentences for the word.\n  OR\n- If the user prompts you with: \"Day [Number]\", you should choose a unique words according to the day number.\n\n2. **Word Format:**\n\n- For each word, provide the following details in the format below:\n\n  - Malay Word: [Word in Malay]\n  - Definition: [Meaning of the word in English]\n  - Example: [very simple and very basic and mini Malay sentence using the word So it will be easier to understand that word and know how to use it, along with its English translation]\n\n- The output format: {\"word\":{\"MALAY_WORD\":\"malay word\",\"DEFINITION\":\"definition\",\"EXAMPLES\":[\"Noun example\", \"Verb example\"],\"EXAMPLE_MEANINGS\":[\"Noun example meaning\",\"Verb example meaning\"]}]}\n\n3. **Response Example:**\n\n- If the user prompts \"Help me learn Malay buku\",Your response should look like this:\n \"{\"word\":{\"MALAY_WORD\":\"buku\",\"DEFINITION\":\"book\",\"EXAMPLES\":[ \"Saya membaca buku.\",\"Buku ini sangat menarik.\"],\"EXAMPLE_MEANINGS\":[\"I am reading a book.\",\"This book is big.\"]}}\"\n\n4. **Task Execution:**\n\n- Do not encapsulate the JSON in markdown\n- The chatbot should only provide the response in the specified format.\n- Focus on clear and concise responses, ensuring practical usage.\n- If the word is ambiguous or not sure respond with a similar word\n- Use emojis where suitable and possible to enhance engagement.\n- Apply capitalization as appropriate"
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

    for _ in {0..3}; do

        while ! RESPONSE=$(curl -s \
            -X POST https://generativelanguage.googleapis.com/v1beta/models/"${GEMINI_MODEL}":generateContent?key="${API_KEY}" \
            -H 'Content-Type: application/json' \
            -d "${PAYLOAD}"); do

            sleep 60

            echo "Error RESPONSE failed" >&2

        done
        # The RESPONSE is correct.

        if [[ $(echo "${RESPONSE}" | jq -r keys[0]) == "error" ]]; then
            sleep 3
            continue
        fi

        RESPONSE_CONTENT=$(echo "${RESPONSE}" | jq -r '.candidates[0].content.parts[0].text')

        # First try to parse directly as JSON
        if RESPONSE=$(echo "${RESPONSE_CONTENT}" | jq -e . 2>/dev/null); then
            # Successfully parsed as direct JSON
            :
        else
            # Try removing markdown code blocks if present
            CLEANED_RESPONSE=$(echo "${RESPONSE_CONTENT}" | sed -e 's/^```json//' -e 's/```$//')

            if ! RESPONSE=$(echo "${CLEANED_RESPONSE}" | jq -e . 2>/dev/null); then

                log_error "Failed to parse JSON response after cleaning"
                continue

            fi
        fi
        construct_message "${RESPONSE}"

        return 0
    done

}

# Format the raw message
construct_message() {

    local MALAY_WORD
    local DEFINITION
    local EXAMPLES
    local EXAMPLE_MEANINGS
    local MESSAGE_BODY=""
    local MESSAGE_TITLE

    # Debug: Log the raw input
    echo "Raw response input:" >>"${LOG_FILE}"
    echo "${1}" >>"${LOG_FILE}"

    # Check if input is valid JSON
    if [[ -z "${1}" ]] || ! echo "${1}" | jq empty >/dev/null 2>&1; then

        log_error "Invalid or empty JSON input to construct_message"
        exit 1

    fi

    # # Extract fields with proper error handling
    # MALAY_WORD=$(echo "${1}" | jq -r '.word.MALAY_WORD? // empty')
    # DEFINITION=$(echo "${1}" | jq -r '.word.DEFINITION? // empty')
    # EXAMPLES=$(echo "${1}" | jq -r '.word.EXAMPLES[]? // empty' | paste -sd "\n" -)
    # EXAMPLE_MEANINGS=$(echo "${1}" | jq -r '.word.EXAMPLE_MEANINGS[]? // empty' | paste -sd "\n" -)

    # With these lines:
    MALAY_WORD=$(echo "${1}" | jq -r '(.word.MALAY_WORD // .word[0].MALAY_WORD)? // empty')
    DEFINITION=$(echo "${1}" | jq -r '(.word.DEFINITION // .word[0].DEFINITION)? // empty')
    EXAMPLES=$(echo "${1}" | jq -r '(.word.EXAMPLES[] // .word[0].EXAMPLES[])? // empty' | paste -sd "\n" -)
    EXAMPLE_MEANINGS=$(echo "${1}" | jq -r '(.word.EXAMPLE_MEANINGS[] // .word[0].EXAMPLE_MEANINGS[])? // empty' | paste -sd "\n" -)

    # Validate we got required fields
    if [[ -z "${MALAY_WORD}" || -z "${DEFINITION}" ]]; then

        log_error "Missing required fields (MALAY_WORD or DEFINITION)"
        exit 1

    fi

    MESSAGE_TITLE="🇲🇾 ${MALAY_WORD} : 🇬🇧 ${DEFINITION}"

    # Combine examples and their meanings
    IFS=$'\n' read -r -d '' -a examples_array <<<"${EXAMPLES}"
    IFS=$'\n' read -r -d '' -a meanings_array <<<"${EXAMPLE_MEANINGS}"

    for i in "${!examples_array[@]}"; do

        MESSAGE_BODY+="${examples_array[$i]}"

        if [[ -n "${meanings_array[$i]:-}" ]]; then

            MESSAGE_BODY+="\n(${meanings_array[$i]})\n"

        fi
    done

    send_notification "${MESSAGE_TITLE}" "${MESSAGE_BODY}"
}

# ARGS: day
fetch_prompt() {

    if file_exists "${WORD_LIST_FILE}"; then

        IFS=',' read -r -a WORDS <<<"$(sed "${1:-1}q;d" "${WORD_LIST_FILE}")"

        echo "Help me learn Malay ${WORDS[0]}"

        return 0

    fi
    # The word list file does not exist

    echo "Day ${1:-1}"

    return 0

}

# output INTERNET=$?
internet() {

    timeout 5 bash -c "</dev/tcp/1.1.1.1/53" >/dev/null 2>&1

    INTERNET=$?

    return "${INTERNET}"

}

main() {
    local DAY_NUMBER

    internet &

    # last accessed date file exist
    if file_exists "${LEARNING_STATE_FILE}"; then

        source "${LEARNING_STATE_FILE}"

        if fetch_new_data "$(fetch_prompt "${DAY_NUMBER}")"; then

            echo -e "DAY_NUMBER=$((DAY_NUMBER + 1))" >"${LEARNING_STATE_FILE}"

        fi

        wait

        return 0

    fi
    # last accessed date file does not exists

    DAY_NUMBER=1

    if fetch_new_data "$(fetch_prompt "${DAY_NUMBER}")"; then

        echo -e "DAY_NUMBER=$((DAY_NUMBER + 1))" >"${LEARNING_STATE_FILE}"

    fi

    wait

    return 0

}

main
