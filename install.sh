#!/usr/bin/env bash

set -o pipefail

SERVICE_NAME="dnstt"
BINARY_PATH="/usr/local/bin/dnstt-server"
KEY_DIR="/etc/dnstt"
PRIVKEY="$KEY_DIR/server.key"
PUBKEY="$KEY_DIR/server.pub"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Detecta idioma a partir do locale do sistema
detect_locale_lang() {
  local l
  l="${LC_ALL:-${LANG:-pt}}"
  l="${l%%.*}"

  case "$l" in
    pt|pt_BR|pt_PT) echo "pt" ;;
    en|en_US|en_GB|en_CA|en_AU|en_*) echo "en" ;;
    *) echo "pt" ;;
  esac
}

# Detecta interface padrão de rede
detect_default_iface() {
  local iface
  if command -v ip >/dev/null 2>&1; then
    iface=$(ip route show default 2>/dev/null | awk '/default/ {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
    if [ -n "$iface" ]; then
      echo "$iface"
      return
    fi
  fi
  echo "eth0"
}

LANG_DNSTT="${DNSTT_LANG:-$(detect_locale_lang)}"
NET_IFACE="${DNSTT_IFACE:-$(detect_default_iface)}"

say() {
  local key="$1"; shift || true
  local rest="$*"
  case "$LANG_DNSTT" in
    en)
      case "$key" in
        must_be_root) echo "This script must be run as root." ;;
        unsupported_arch) echo "Unsupported architecture: $rest" ;;
        detected_iface) echo "Using network interface: $rest" ;;

        downloading) echo "Downloading dnstt-server from: $rest" ;;
        download_failed) echo "Failed to download DNSTT binary." ;;

        binary_installed) echo "DNSTT installed at: $rest" ;;
        binary_missing) echo "Binary not found or not executable at $rest. Aborting installation." ;;
        binary_invalid) echo "Downloaded file does not appear to be a valid DNSTT binary (execution failed)." ;;

        keys_exist) echo "Keys already exist in $rest, keeping them." ;;

        generating_keys) echo "Generating DNSTT private and public keys..." ;;
        keygen_failed) echo "Failed to generate DNSTT keys." ;;

        keys_generated) echo "Keys generated at:" ;;
        priv_path) echo "  Private: $rest" ;;
        pub_path) echo "  Public: $rest" ;;

        configuring_firewall) echo "Configuring firewall rules..." ;;
        iptables_missing) echo "iptables not found, skipping IPv4 rules." ;;
        ip6tables_missing) echo "ip6tables not found, skipping IPv6 rules." ;;

        creating_service) echo "Creating systemd service file at $rest..." ;;

        starting_service) echo "Starting $SERVICE_NAME service..." ;;
        service_not_installed) echo "Service $SERVICE_NAME is not installed. Run 'dnstt install <ns-domain> <upstream>' first." ;;
        service_start_failed) echo "Failed to start $SERVICE_NAME service." ;;
        service_stop_failed) echo "Failed to stop $SERVICE_NAME service." ;;
        service_restart_failed) echo "Failed to restart $SERVICE_NAME service." ;;
        service_active) echo "Service $SERVICE_NAME is active (running)." ;;
        service_inactive) echo "Service $SERVICE_NAME is not active." ;;

        install_start) echo "Starting DNSTT installation..." ;;
        install_done) echo "Installation finished." ;;

        restart_service) echo "Restarting $SERVICE_NAME service..." ;;
        start_service) echo "Starting $SERVICE_NAME service..." ;;
        stop_service) echo "Stopping $SERVICE_NAME service..." ;;
        uninstall_start) echo "Starting DNSTT uninstall..." ;;
        uninstall_done) echo "Uninstall finished. Binary, keys and service removed." ;;

        invalid_install_args) echo "To install, you must provide NS domain and upstream target." ;;

        unknown_cmd) echo "Unknown command: $rest" ;;

        no_pubkey) echo "Public key not found at $rest." ;;
        run_install_first) echo "You may need to run installation first:" ;;

        show_logs_header) echo "Last 100 log lines for service $SERVICE_NAME:" ;;
        watch_logs_header) echo "Following logs for service $SERVICE_NAME (Ctrl+C to exit)..." ;;
      esac
      ;;
    *)
      case "$key" in
        must_be_root) echo "Este script deve ser executado como root." ;;
        unsupported_arch) echo "Arquitetura não suportada: $rest" ;;
        detected_iface) echo "Usando interface de rede: $rest" ;;

        downloading) echo "Baixando dnstt-server a partir de: $rest" ;;
        download_failed) echo "Falha ao baixar o binário do DNSTT." ;;

        binary_installed) echo "dnstt instalado em: $rest" ;;
        binary_missing) echo "Binário não encontrado ou não executável em $rest. Abortando instalação." ;;
        binary_invalid) echo "O arquivo baixado não parece ser um binário válido do DNSTT (execução falhou)." ;;

        keys_exist) echo "Chaves já existem em $rest, mantendo-as." ;;

        generating_keys) echo "Gerando chave privada e pública do DNSTT..." ;;
        keygen_failed) echo "Falha ao gerar as chaves do DNSTT." ;;

        keys_generated) echo "Chaves geradas em:" ;;
        priv_path) echo "  Privada: $rest" ;;
        pub_path) echo "  Pública: $rest" ;;

        configuring_firewall) echo "Configurando regras de firewall..." ;;
        iptables_missing) echo "iptables não encontrado, ignorando regras IPv4." ;;
        ip6tables_missing) echo "ip6tables não encontrado, ignorando regras IPv6." ;;

        creating_service) echo "Criando arquivo de serviço systemd em $rest..." ;;

        starting_service) echo "Iniciando serviço $SERVICE_NAME..." ;;
        service_not_installed) echo "Serviço $SERVICE_NAME não está instalado. Execute 'dnstt install <dominio-NS> <upstream>' antes." ;;
        service_start_failed) echo "Falha ao iniciar o serviço $SERVICE_NAME." ;;
        service_stop_failed) echo "Falha ao parar o serviço $SERVICE_NAME." ;;
        service_restart_failed) echo "Falha ao reiniciar o serviço $SERVICE_NAME." ;;
        service_active) echo "Serviço $SERVICE_NAME está ativo (em execução)." ;;
        service_inactive) echo "Serviço $SERVICE_NAME não está ativo." ;;

        install_start) echo "Iniciando instalação do DNSTT..." ;;
        install_done) echo "Instalação concluída." ;;

        restart_service) echo "Reiniciando serviço $SERVICE_NAME..." ;;
        start_service) echo "Iniciando serviço $SERVICE_NAME..." ;;
        stop_service) echo "Parando serviço $SERVICE_NAME..." ;;
        uninstall_start) echo "Iniciando desinstalação do DNSTT..." ;;
        uninstall_done) echo "Desinstalação concluída. Binário, chaves e serviço removidos." ;;

        invalid_install_args) echo "Para instalar, informe domínio NS e alvo (upstream)." ;;

        unknown_cmd) echo "Comando desconhecido: $rest" ;;

        no_pubkey) echo "Chave pública não encontrada em $rest." ;;
        run_install_first) echo "Talvez seja necessário rodar a instalação primeiro:" ;;

        show_logs_header) echo "Últimas 100 linhas de log do serviço $SERVICE_NAME:" ;;
        watch_logs_header) echo "Acompanhando logs do serviço $SERVICE_NAME (Ctrl+C para sair)..." ;;
      esac
      ;;
  esac
}

usage() {
  if [ "$LANG_DNSTT" = "en" ]; then
    cat << 'USAGE'
Usage: dnstt <command> [options]

Commands:
  install <ns-domain> <upstream>   Install and configure DNSTT
                                   ns-domain: e.g. ns.yourdomain.com
                                   upstream : target TCP, e.g. 127.0.0.1:22
  start                            Start the dnstt service
  stop                             Stop the dnstt service
  restart                          Restart the dnstt service
  status                           Show dnstt service status
  pubkey                           Show server public key
  logs                             Show the last log lines
  logs-watch                       Follow logs in real time
  uninstall                        Stop service and remove binary, keys and unit

Global options:
  --lang [pt|en]                   Choose language (default: from locale)
  -h, --help                       Show this help
USAGE
  else
    cat << 'USAGE'
Uso: dnstt <comando> [opções]

Comandos:
  install <dominio-NS> <upstream>  Instala e configura o DNSTT
                                   dominio-NS: ex. ns.seudominio.com
                                   upstream  : destino TCP, ex. 127.0.0.1:22
  start                            Inicia o serviço dnstt
  stop                             Para o serviço dnstt
  restart                          Reinicia o serviço dnstt
  status                           Mostra o status do serviço dnstt
  pubkey                           Mostra a chave pública do servidor
  logs                             Mostra as últimas linhas de log
  logs-watch                       Acompanha os logs em tempo real
  uninstall                        Para o serviço e remove binário, chaves e unit

Opções globais:
  --lang [pt|en]                   Seleciona o idioma (padrão: locale)
  -h, --help                       Mostra esta ajuda
USAGE
  fi
}

require_root() {
  if [ "$EUID" -ne 0 ]; then
    say must_be_root >&2
    exit 1
  fi
}

identify_arch() {
  local arch
  arch=$(uname -m)

  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    i686|i386) echo "386" ;;
    armv7l) echo "armv7" ;;
    *) echo "unsupported" ;;
  esac
}

download_binary() {
  local arch url
  arch=$(identify_arch)

  if [ "$arch" = "unsupported" ]; then
    say unsupported_arch "$(uname -m)" >&2
    exit 1
  fi

  case "$arch" in
    amd64) url="https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-amd64" ;;
    arm64) url="https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-arm64" ;;
    386)   url="https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-386" ;;
    armv7) url="https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-armv7" ;;
  esac

  say downloading "$url"

  mkdir -p "$(dirname "$BINARY_PATH")"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL -o "$BINARY_PATH" "$url"; then
      say download_failed >&2
      rm -f "$BINARY_PATH"
      exit 1
    fi
  else
    if ! wget -qO "$BINARY_PATH" "$url"; then
      say download_failed >&2
      rm -f "$BINARY_PATH"
      exit 1
    fi
  fi

  chmod +x "$BINARY_PATH"

  if ! "$BINARY_PATH" -h >/dev/null 2>&1; then
    say binary_invalid >&2
    rm -f "$BINARY_PATH"
    exit 1
  fi

  say binary_installed "$BINARY_PATH"
}

generate_keys() {
  if [ ! -x "$BINARY_PATH" ]; then
    say binary_missing "$BINARY_PATH" >&2
    exit 1
  fi

  mkdir -p "$KEY_DIR"

  if [ -f "$PRIVKEY" ] || [ -f "$PUBKEY" ]; then
    say keys_exist "$KEY_DIR"
    return
  fi

  say generating_keys
  if ! "$BINARY_PATH" -gen-key -privkey-file "$PRIVKEY" -pubkey-file "$PUBKEY" >/dev/null 2>&1; then
    say keygen_failed >&2
    rm -f "$PRIVKEY" "$PUBKEY"
    exit 1
  fi

  say keys_generated
  say priv_path "$PRIVKEY"
  say pub_path "$PUBKEY"
}

setup_firewall() {
  say detected_iface "$NET_IFACE"
  say configuring_firewall

  if command -v iptables >/dev/null 2>&1; then
    iptables -I INPUT -p udp --dport 53   -j ACCEPT >/dev/null 2>&1 || true
    iptables -I INPUT -p udp --dport 5300 -j ACCEPT >/dev/null 2>&1 || true
    iptables -t nat -A PREROUTING -i "$NET_IFACE" -p udp --dport 53 -j REDIRECT --to-port 5300 >/dev/null 2>&1 || true
  else
    say iptables_missing >&2
  fi

  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -I INPUT -p udp --dport 53   -j ACCEPT >/dev/null 2>&1 || true
    ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT >/dev/null 2>&1 || true
    ip6tables -t nat -A PREROUTING -i "$NET_IFACE" -p udp --dport 53 -j REDIRECT --to-port 5300 >/dev/null 2>&1 || true
  else
    say ip6tables_missing >&2
  fi
}

create_service() {
  local domain="$1"
  local upstream="$2"

  say creating_service "$SERVICE_FILE"

  cat > "$SERVICE_FILE" <<EOF_UNIT
[Unit]
Description=DNSTT Tunnel Server
After=network.target syslog.target

[Service]
Type=simple
User=root
ExecStart=$BINARY_PATH -udp [::]:5300 -privkey-file $PRIVKEY $domain $upstream
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF_UNIT

  chmod 644 "$SERVICE_FILE"
  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
}

show_pubkey() {
  if [ -f "$PUBKEY" ]; then
    local key
    key=$(cat "$PUBKEY")
    if [ "$LANG_DNSTT" = "en" ]; then
      echo "Server public key: $key"
    else
      echo "Chave pública do servidor: $key"
    fi
  else
    say no_pubkey "$PUBKEY" >&2
    say run_install_first >&2
    if [ "$LANG_DNSTT" = "en" ]; then
      echo "  dnstt install <ns-domain> <upstream>" >&2
    else
      echo "  dnstt install <dominio-NS> <upstream>" >&2
    fi
    exit 1
  fi
}

show_logs() {
  say show_logs_header
  journalctl -u "$SERVICE_NAME" --no-pager | tail -n 100
}

watch_logs() {
  say watch_logs_header
  journalctl -u "$SERVICE_NAME" -f
}

service_exists() {
  [ -f "$SERVICE_FILE" ]
}

install_dnstt() {
  local domain="$1"
  local upstream="$2"

  say install_start
  echo

  download_binary
  echo

  generate_keys
  echo

  setup_firewall
  echo

  create_service "$domain" "$upstream"
  echo

  say starting_service
  if ! systemctl restart "$SERVICE_NAME" >/dev/null 2>&1; then
    say service_restart_failed >&2
    if [ "$LANG_DNSTT" = "en" ]; then
      echo "Run 'systemctl status dnstt -l' for details." >&2
    else
      echo "Execute 'systemctl status dnstt -l' para detalhes." >&2
    fi
    exit 1
  fi

  if systemctl is-active --quiet "$SERVICE_NAME"; then
    say service_active
  else
    say service_inactive >&2
    if [ "$LANG_DNSTT" = "en" ]; then
      echo "Run 'systemctl status dnstt -l' for diagnostic details." >&2
    else
      echo "Execute 'systemctl status dnstt -l' para detalhes de diagnóstico." >&2
    fi
    exit 1
  fi

  echo
  say install_done
  echo
  show_pubkey
}

uninstall_dnstt() {
  say uninstall_start

  systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
  systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true

  rm -f "$SERVICE_FILE"
  systemctl daemon-reload >/dev/null 2>&1 || true

  rm -f "$BINARY_PATH"
  rm -rf "$KEY_DIR"

  say uninstall_done
  if [ "$LANG_DNSTT" = "en" ]; then
    echo "Note: iptables/ip6tables rules added during installation were not automatically reverted."
  else
    echo "Nota: as regras de iptables/ip6tables adicionadas na instalação não foram revertidas automaticamente."
  fi
}

status_dnstt() {
  if ! service_exists; then
    say service_not_installed
    exit 1
  fi

  if systemctl is-active --quiet "$SERVICE_NAME"; then
    say service_active
  else
    say service_inactive
  fi
}

start_dnstt() {
  if ! service_exists; then
    say service_not_installed
    exit 1
  fi

  say start_service
  if ! systemctl start "$SERVICE_NAME" >/dev/null 2>&1; then
    say service_start_failed >&2
    exit 1
  fi

  status_dnstt
}

stop_dnstt() {
  if ! service_exists; then
    say service_not_installed
    exit 1
  fi

  say stop_service
  if ! systemctl stop "$SERVICE_NAME" >/dev/null 2>&1; then
    say service_stop_failed >&2
    exit 1
  fi

  status_dnstt
}

restart_dnstt() {
  if ! service_exists; then
    say service_not_installed
    exit 1
  fi

  say restart_service
  if ! systemctl restart "$SERVICE_NAME" >/dev/null 2>&1; then
    say service_restart_failed >&2
    exit 1
  fi

  status_dnstt
}

main() {
  local args=()
  local saw_help=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --lang)
        shift || true
        LANG_DNSTT="${1:-$LANG_DNSTT}"
        ;;
      --lang=*)
        LANG_DNSTT="${1#--lang=}"
        ;;
      -l)
        shift || true
        LANG_DNSTT="${1:-$LANG_DNSTT}"
        ;;
      --help|-h)
        saw_help=1
        ;;
      *)
        args+=("$1")
        ;;
    esac
    shift || true
  done

  case "$LANG_DNSTT" in
    en|pt) ;;
    *) LANG_DNSTT="$(detect_locale_lang)" ;;
  esac

  set -- "${args[@]}"

  local cmd=""
  if [ "$saw_help" -eq 1 ] && [ $# -eq 0 ]; then
    cmd="help"
  elif [ $# -gt 0 ]; then
    cmd="$1"
    shift || true
  else
    cmd="help"
  fi

  if [ "$cmd" = "help" ]; then
    usage
    exit 0
  fi

  require_root

  case "$cmd" in
    install)
      local domain upstream
      domain="${1:-}"
      upstream="${2:-}"

      if [ -z "$domain" ] || [ -z "$upstream" ]; then
        say invalid_install_args >&2
        echo >&2
        usage >&2
        exit 1
      fi

      install_dnstt "$domain" "$upstream"
      ;;
    start)
      start_dnstt
      ;;
    stop)
      stop_dnstt
      ;;
    restart)
      restart_dnstt
      ;;
    status)
      status_dnstt
      ;;
    pubkey)
      show_pubkey
      ;;
    logs)
      show_logs
      ;;
    logs-watch)
      watch_logs
      ;;
    uninstall)
      uninstall_dnstt
      ;;
    *)
      say unknown_cmd "$cmd" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
