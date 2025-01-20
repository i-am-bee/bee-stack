#!/bin/bash

# shellcheck disable=SC2059
# disable "no variables in printf" due to color codes

REQUIRED_COMPOSE_VERSION=2.26
ORANGE='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color
TMP_ENV_FILE=.env.tmp

set -e

print_error() {
    printf "${ORANGE}❗ERROR: %s${NC}\n" "$1"
    shift
    [ -n "$1" ] && printf "${ORANGE}❗       %s${NC}\n" "$@"
    printf "❗\n${ORANGE}❗Visit the troubleshooting guide:\n"
    printf "❗${BLUE}https://github.com/i-am-bee/bee-stack/blob/main/docs/troubleshooting.md${NC}\n"
}

print_header() {
  printf "${BLUE}%s${NC}\n" "$1"
}

MISSING_COMPOSE_MSG=$(cat << EOF
For installation instructions, see:
- ${BLUE}Podman desktop:${NC} https://podman.io
  ⚠️ install using the official installer (not through package manager like brew, apt, etc.)
  ⚠️ use rootful machine (default)
  ⚠️ use docker compatibility mode
- ${BLUE}Rancher desktop:${NC} https://rancherdesktop.io
- ${BLUE}Docker desktop:${NC} https://www.docker.com/
EOF
)

choose() {
  print_header "${1}:"
  local range="[1-$(($# - 1))]"

  for ((i=1; i < $#; i++)); do
    choice=$((i+1))
    echo "[${i}]: ${!choice}"
  done

  while true; do
    read -rp "Select ${range}: " SELECTED_NUM
    if ! [[ "$SELECTED_NUM" =~ ^[0-9]+$ ]]; then print_error "Please enter a valid number"; continue; fi
    if [ "$SELECTED_NUM" -lt 1 ] || [ "$SELECTED_NUM" -ge "$#" ]; then
      print_error "Number is not in ${range}"; continue;
    fi
    break
  done

  local idx=$((SELECTED_NUM + 1))
  SELECTED_OPT="${!idx}"
}

ask_yes_no() {
  local answer
  read -rp "${1} (Y/n): " answer
  answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
  [ "$answer" = "y" ] && echo "yes" || echo "no"
}

check_docker() {
    # Check if docker or podman is installed
    local runtime compose_version major minor req_major req_minor
    req_major=$(cut -d'.' -f1 <<< ${REQUIRED_COMPOSE_VERSION})
    req_minor=$(cut -d'.' -f2 <<< ${REQUIRED_COMPOSE_VERSION})
    
    
    local existing_runtimes=()
    for runtime in docker podman; do
      command -v "$runtime" &>/dev/null && existing_runtimes+=("$runtime")
    done

    if [ ${#existing_runtimes[@]} -eq 0 ]; then
      print_error "None of the supported container runtimes are installed (docker, rancher, or podman)"
      printf "\n${MISSING_COMPOSE_MSG}"
      exit 1
    fi
    
    local runtimes_with_compose=()
    for runtime in "${existing_runtimes[@]}"; do
        "$runtime" compose version --short &>/dev/null && runtimes_with_compose+=("$runtime")
    done
    
    if [ ${#runtimes_with_compose[@]} -eq 0 ]; then
      print_error "Compose extension is not installed for any of the existing runtimes: ${existing_runtimes[*]}"
      printf "\n${MISSING_COMPOSE_MSG}"
      exit 2
    fi
    
    local compose_versions=()
    local compose_version_ok=0
    for runtime in "${runtimes_with_compose[@]}"; do
      compose_version=$("$runtime" compose version --short || echo "compose_not_found")

      major=$(cut -d'.' -f1 <<< "$compose_version")
      minor=$(cut -d'.' -f2 <<< "$compose_version")

      compose_versions+=("${runtime} compose ($compose_version)")
      if [ "$major" -gt "$req_major" ] || { [ "$major" -eq "$req_major" ] && [ "$minor" -ge "$req_minor" ]; }; then
        compose_version_ok=1
        break
      fi
    done

    compose_versions_print=$(IFS=','; echo "${compose_versions[*]}" | sed 's/,/, /g')

    if [ "$compose_version_ok" -eq 0 ]; then
        print_error "None of compose command versions meets the required version ${REQUIRED_COMPOSE_VERSION}." \
                    "Found versions: ${compose_versions_print}" \
                    "Please (re)install a supported runtime"
        echo ""
        printf "${MISSING_COMPOSE_MSG}\n"
        exit 2
    fi
    RUNTIME="$runtime"
}

trim() {
    local var="${1#"${1%%[![:space:]]*}"}"
    echo "${var%"${var##*[![:space:]]}"}"
}

write_env() {
  local default_prompt default_provided value
  default_provided=$([ $# -gt 1 ] && echo 1 || echo 0)
  default_prompt="$([ "$default_provided" -eq 1 ] && echo " (leave empty for default '${2}')" || echo "")"
  while true; do
    read -rp "Provide ${1}${default_prompt}: " value
    if [ -z "$value" ] && [ "$default_provided" -eq 0 ]; then
      print_error "Value is required"
      continue
    fi
    break
  done
  value="$([ -z "$value" ] && echo "$2" || echo "$value")"
  value="$(trim "$value")"
  echo "$1=$value" >> "$TMP_ENV_FILE"
  export "${1}=${value}"
}

write_backend() {
  echo AI_BACKEND="$1" >> "$TMP_ENV_FILE"
  echo EMBEDDING_BACKEND="$1" >> "$TMP_ENV_FILE"
}

configure_watsonx() {
  write_backend watsonx
  write_env WATSONX_PROJECT_ID
  write_env WATSONX_API_KEY
  write_env WATSONX_REGION "us-south"
}

ollama_config_error() {
  print_error "Ollama is not running or accessible from containers."
  printf "  Make sure you configured OLLAMA_HOST=0.0.0.0\n"
  printf "  see https://github.com/ollama/ollama/blob/main/docs/faq.md#how-do-i-configure-ollama-server\n"
  printf "  or run ollama from command line ${BLUE}OLLAMA_HOST=0.0.0.0 ollama serve${NC}\n"
  printf "  Do not forget to pull the required LLMs ${BLUE}ollama pull llama3.1${NC}\n"
  exit 2
}

configure_ollama() {
  write_backend ollama
  write_env OLLAMA_URL "http://host.docker.internal:11434"
  print_header "Checking Ollama connection"

  if [ "$(uname)" = "Linux" ] && grep -q OLLAMA_URL="http://host.docker.internal:11434" .env; then
    if ! ${RUNTIME} run --rm -it --user root --entrypoint sh curlimages/curl -c "echo \"\$(ip route | awk '/default/ { print \$3 }') host.docker.internal\" >> /etc/hosts && curl ${OLLAMA_URL}"; then
      ollama_config_error
    fi
  else
    if ! ${RUNTIME} run --rm -it curlimages/curl "$OLLAMA_URL"; then
      ollama_config_error
    fi
  fi
  printf "\n"
}

configure_openai() {
  write_backend openai
  write_env OPENAI_API_KEY
}

configure_text_extraction() {
  echo FEATURE_FLAGS=\''{"Knowledge":true,"Files":true,"TextExtraction":true,"FunctionTools":true,"Observe":true,"Projects":true}'\' >> "$TMP_ENV_FILE"
  echo TEXT_EXTRACTION_ENABLED=true >> "$TMP_ENV_FILE"
  echo EXTRACTION_BACKEND=docling >> "$TMP_ENV_FILE"
}

configure_no_text_extraction() {
  echo FEATURE_FLAGS=\''{"Knowledge":false,"Files":true,"TextExtraction":false,"FunctionTools":true,"Observe":true,"Projects":true}'\' >> "$TMP_ENV_FILE"
  echo EXTRACTION_BACKEND=wdu >> "$TMP_ENV_FILE"
}

setup() {
  printf "🐝 Welcome to the bee-stack! You're just a few questions away from building agents!\n(Press ^C to exit)\n\n"
  rm -f "$TMP_ENV_FILE"
  choose "Choose LLM provider" "watsonx" "ollama" "openai"
  [[ $SELECTED_OPT == 'ollama' ]] && configure_ollama
  [[ $SELECTED_OPT == 'watsonx' ]] && configure_watsonx
  [[ $SELECTED_OPT == 'openai' ]] && configure_openai

  text_extraction_enabled=$(ask_yes_no \
    "Do you want to enable docling text extraction? ⚠️ Requires >= 15GB of RAM **CONFIGURED** for the container runtime ⚠️"
  )
  if [[ $text_extraction_enabled == 'yes' ]]; then
    configure_text_extraction
  else
    configure_no_text_extraction
  fi

  if [ -f ".env" ]; then
    [ "$(ask_yes_no ".env file already exists. Do you want to override it?")" = 'no' ] && exit 1
    if [ -n "$(${RUNTIME} compose ps -aq)" ]; then
      [ "$(ask_yes_no "bee-stack data must be removed when changing configuration, are you sure?")" = 'no' ] && exit 1
      clean_stack
    fi
  fi

  cp "$TMP_ENV_FILE" .env
  [ "$(ask_yes_no "Do you want to start bee-stack now?")" = 'yes' ] && start_stack
}

start_stack() {
  if ! [ -f ".env" ]; then
    [ "$(ask_yes_no "bee-stack is not yet configured, do you want to configure it now?")" = 'yes' ] && setup || exit 3
  fi

  ${RUNTIME} compose --profile all up -d

  if grep -q TEXT_EXTRACTION_ENABLED=true .env; then
    ${RUNTIME} compose --profile text-extraction up -d
  fi
  if [ "$(uname)" = "Linux" ] && grep -q AI_BACKEND="ollama" .env; then
    docker exec bee-stack-bee-api-1 sh -c "echo \"\$(ip route | awk '/default/ { print \$3 }' | head -n 1)      host.docker.internal\" | tee -a /etc/hosts > /dev/null"
  fi
  printf "Done. You can visit the UI at ${BLUE}http://localhost:3000${NC}\n"
}

stop_stack() {
  ${RUNTIME} compose --profile all down
  ${RUNTIME} compose --profile infra down
  ${RUNTIME} compose --profile text-extraction down
}

clean_stack() {
  ${RUNTIME} compose --profile all down --volumes
  ${RUNTIME} compose --profile infra down --volumes
  ${RUNTIME} compose --profile text-extraction down --volumes
  rm -rf tmp
  mkdir -p ./tmp/code-interpreter-storage
}

start_infra() {
  mkdir -p ./tmp/code-interpreter-storage
  ${RUNTIME} compose --profile infra up -d
}

dump_logs() {
  timestamp=$(date +"%Y-%m-%d_%H%MS")
  folder="./logs/${timestamp}"
  mkdir -p "${folder}"

  for component in $(${RUNTIME} compose --profile all config --services); do
    ${RUNTIME} compose logs "${component}" > "${folder}/${component}.log"
  done

  ${RUNTIME} version > "${folder}/${RUNTIME}.log"
  ${RUNTIME} compose version > "${folder}/${RUNTIME}.log"

  zip -r "${folder}.zip" "${folder}/"|| echo "Zip is not installed, please upload individual logs"

  printf "${ORANGE}Logs were created in ${folder}${NC}.\n"
  printf "If you have issues running bee-stack, please create an issue "
  printf "and attach the file ${ORANGE}${folder}.zip${NC} at:\n"
  printf "${BLUE}https://github.com/i-am-bee/bee-stack/issues/new?template=run_stack_issue.md${NC}\n"
}

# Main
check_docker
command=$(trim "$1" | tr '[:upper:]' '[:lower:]')
command=$([ -z "$command" ] && echo "setup" || echo "$command")
if [ "$command" = 'setup' ]; then setup
elif [ "$command" = 'start' ]; then start_stack
elif [ "$command" = 'start:infra' ]; then start_infra
elif [ "$command" = 'stop' ]; then stop_stack
elif [ "$command" = 'clean' ]; then clean_stack
elif [ "$command" = 'check' ]; then check_docker
elif [ "$command" = 'logs' ]; then dump_logs
else print_error "Unknown command $1"
fi
