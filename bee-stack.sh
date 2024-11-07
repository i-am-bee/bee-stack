#!/bin/bash

# shellcheck disable=SC2059
# disable "no variables in printf" due to color codes

REQUIRED_COMPOSE_VERSION=2.29
ORANGE='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color
TMP_ENV_FILE=.env.tmp

set -e

print_error() {
    printf "${ORANGE}❗ERROR: %s${NC}\n" "$1"
    shift
    [ -n "$1" ] && printf "${ORANGE}❗       %s${NC}\n" "$@"
    true
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
  echo LLM_BACKEND="$1" >> "$TMP_ENV_FILE"
  echo EMBEDDING_BACKEND="$1" >> "$TMP_ENV_FILE"
}

configure_bam() {
  write_backend bam
  write_env BAM_API_KEY
}

configure_watsonx() {
  write_backend watsonx
  write_env WATSONX_PROJECT_ID
  write_env WATSONX_API_KEY
  write_env WATSONX_REGION "us-south"
}

configure_ollama() {
  write_backend ollama
  write_env OLLAMA_URL "http://host.docker.internal:11434"
  print_header "Checking Ollama connection"
  if ! docker run --rm -it curlimages/curl "$OLLAMA_URL"; then
    print_error "Ollama is not running or accessible from containers."
    printf "  Make sure you configured OLLAMA_HOST=0.0.0.0\n"
    printf "  see https://github.com/ollama/ollama/blob/main/docs/faq.md#how-do-i-configure-ollama-server\n"
    printf "  or run ollama from command line ${BLUE}OLLAMA_HOST=0.0.0.0 ollama serve${NC}\n"
    printf "  Do not forget to pull the required LLMs ${BLUE}ollama pull llama3.1${NC}\n"
    exit 2
  fi
}

configure_openai() {
  write_backend openai
  write_env OPENAI_API_KEY
}

setup() {
  printf "🐝 Welcome to the bee-stack! You're just a few questions away from building agents!\n(Press ^C to exit)\n\n"
  rm -f "$TMP_ENV_FILE"
  choose "Choose LLM provider" "watsonx" "ollama" "bam" "openai"
  [[ $SELECTED_OPT == 'bam' ]] && configure_bam
  [[ $SELECTED_OPT == 'ollama' ]] && configure_ollama
  [[ $SELECTED_OPT == 'watsonx' ]] && configure_watsonx
  [[ $SELECTED_OPT == 'openai' ]] && configure_openai

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
}

stop_stack() {
  ${RUNTIME} compose --profile all down
}

clean_stack() {
  ${RUNTIME} compose --profile all down --volumes
}

start_infra() {
  ${RUNTIME} compose --profile infra up -d
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
else print_error "Unknown command $1"
fi