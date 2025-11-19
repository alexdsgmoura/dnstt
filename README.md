# DNSTT Server – Guia de Instalação e Uso

## 🔎 Visão Geral

O **DNSTT Server** é o componente responsável por manter túneis através de DNS, encaminhando o tráfego recebido na porta UDP 53/5300 para um servidor TCP interno (por exemplo, um servidor SSH em `127.0.0.1:22`).

Este repositório distribui:

- Binário oficial `dnstt-server` (servidor principal).
- Script de gerenciamento `dnstt`, que:
  - Detecta arquitetura automaticamente.
  - Instala o binário em `/usr/local/bin`.
  - Gera chaves privada/pública.
  - Configura regras básicas de firewall (iptables/ip6tables).
  - Cria e gerencia o serviço `systemd` (`dnstt.service`).

---

## ⚙️ Pré-requisitos

- Distribuição Linux com **systemd** (testado em Ubuntu/Debian).
- Acesso **root** (`sudo`) para instalar binários, criar serviço e ajustar firewall.
- Ferramentas padrão:
  - `curl` ou `wget`
  - `iptables` / `ip6tables`
  - `ip` (para detectar interface de rede)

---

## 🚀 Instalação Automática (Recomendada)

### 1. Instalar o script `dnstt`

Baixe o script de gerenciamento e torne-o executável (ajuste a URL conforme a estrutura do seu repositório):

```bash
sudo curl -fsSL https://raw.githubusercontent.com/alexdsgmoura/dnstt/main/dnstt -o /usr/local/bin/dnstt
sudo chmod +x /usr/local/bin/dnstt
````

### 2. Executar a instalação automática do servidor

Use o comando abaixo, informando o seu domínio NS e o destino TCP:

```bash
sudo dnstt install ns.seudominio.com 127.0.0.1:22
```

> Exemplo: se o servidor SSH estiver em `127.0.0.1:22`, esse será o `upstream` padrão.

### O que o script `dnstt` faz durante a instalação

* Detecta a arquitetura (`amd64`, `arm64`, `386`, `armv7`).
* Baixa o binário correto do repositório de releases:

  * `/usr/local/bin/dnstt-server`
* Gera a chave privada e a chave pública do servidor:

  * `/etc/dnstt/server.key`
  * `/etc/dnstt/server.pub`
* Abre as portas necessárias no firewall:

  * UDP 53 e 5300 (IPv4 e IPv6)
  * Redireciona UDP 53 → 5300 na interface padrão detectada (ex.: `eth0`, `ens3`, etc.)
* Cria o serviço `systemd` em:

  * `/etc/systemd/system/dnstt.service`
* Inicia o serviço e exibe a **chave pública** no final da instalação.

---

## 📦 Instalação Manual (Passo a Passo)

Caso prefira não usar o script automático, você pode instalar tudo manualmente.

### 1. Verificar a arquitetura

```bash
uname -m
```

### 2. Baixar o binário de acordo com a arquitetura

```bash
# x86_64
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-amd64

# aarch64 (arm64)
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-arm64

# i686 ou i386
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-386

# armv7l
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-armv7
```

### 3. Dar permissão de execução

```bash
chmod +x /usr/local/bin/dnstt-server
```

### 4. Gerar chave privada e pública

Criar diretório para as chaves:

```bash
mkdir -p /etc/dnstt
```

Gerar as chaves:

```bash
/usr/local/bin/dnstt-server -gen-key -privkey-file /etc/dnstt/server.key -pubkey-file /etc/dnstt/server.pub
```

### 5. Obter a chave pública (para configurar o cliente)

```bash
cat /etc/dnstt/server.pub
```

Guarde essa chave — ela será usada na configuração do cliente DNSTT.

### 6. Configurar o firewall

Abrir portas UDP (IPv4):

```bash
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
```

Abrir portas UDP (IPv6):

```bash
ip6tables -I INPUT -p udp --dport 53 -j ACCEPT
ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT
```

Redirecionar porta 53 → 5300 (IPv4):

```bash
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-port 5300
```

Redirecionar porta 53 → 5300 (IPv6):

```bash
ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-port 5300
```

> Ajuste `eth0` para a interface correta do seu servidor, se necessário.

### 7. Criar o serviço systemd

Criar o arquivo de serviço:

```bash
nano /etc/systemd/system/dnstt.service
```

Conteúdo do serviço:

```ini
[Unit]
Description=DNSTT Tunnel Server
After=network.target syslog.target

[Service]
Type=simple
User=root

ExecStart=/usr/local/bin/dnstt-server -udp [::]:5300 -privkey-file /etc/dnstt/server.key ns.seudominio.com 127.0.0.1:22

Restart=always
RestartSec=3

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 8. Recarregar, habilitar e iniciar o serviço

```bash
# Recarrega a lista de serviços
systemctl daemon-reload

# Habilita o serviço na inicialização
systemctl enable dnstt

# Inicia o serviço
systemctl start dnstt

# Verificar status do serviço
systemctl status dnstt

# Monitorar logs
journalctl -u dnstt -f
```

---

## 🛠 Gerenciamento com `dnstt`

Após instalar o script `dnstt` em `/usr/local/bin/dnstt`, você pode gerenciar o serviço de forma simples:

```bash
# Instalação (baixa binário, gera chaves, firewall, systemd)
sudo dnstt install ns.seudominio.com 127.0.0.1:22

# Iniciar / parar / reiniciar serviço
sudo dnstt start
sudo dnstt stop
sudo dnstt restart

# Ver status do serviço
sudo dnstt status

# Exibir chave pública do servidor
sudo dnstt pubkey

# Ver logs
sudo dnstt logs

# Ver logs em tempo real (watch)
sudo dnstt logs-watch

# Desinstalar completamente (binário, chaves, serviço)
sudo dnstt uninstall
```

Se você tentar rodar `dnstt install` quando o serviço/binário já existem, o script avisa que o DNSTT já parece estar instalado e não continua, para evitar reconfiguração acidental.

---

## 🌐 Idioma e Interface de Rede

### Idioma

O script `dnstt` detecta automaticamente o idioma usando o `locale` do sistema:

* `pt_PT`, `pt_BR`, etc. → mensagens em **português**
* `en_US`, `en_GB`, etc. → mensagens em **inglês**

Você pode forçar o idioma com:

```bash
DNSTT_LANG=pt dnstt status
DNSTT_LANG=en dnstt status
```

Ou com parâmetro:

```bash
dnstt --lang pt status
dnstt --lang en status
```

### Interface de rede

Por padrão, o script detecta automaticamente a interface usada como rota padrão (ex.: `eth0`, `ens3`, etc.) e aplica as regras de redirecionamento nela.

Se quiser sobrescrever manualmente:

```bash
DNSTT_IFACE=eth0 dnstt install ns.seudominio.com 127.0.0.1:22
```

---

## 🔁 Atualização

### Usando o script `dnstt`

Hoje o fluxo recomendado é:

1. Parar e remover instalação existente:

```bash
sudo dnstt uninstall
```

2. Executar novamente a instalação:

```bash
sudo dnstt install ns.seudominio.com 127.0.0.1:22
```

> Isso garante binário, chaves (se necessário), firewall e serviço `systemd` em ordem.

### Atualização manual apenas do binário

Se preferir apenas atualizar o binário:

```bash
sudo systemctl stop dnstt

# Baixe novamente o binário da arquitetura correta para /usr/local/bin/dnstt-server
# (veja a seção de instalação manual)

sudo chmod +x /usr/local/bin/dnstt-server
sudo systemctl start dnstt
```

---

## 🗑 Remoção Manual Completa

Se não quiser usar `dnstt uninstall`, você pode remover tudo manualmente:

```bash
sudo systemctl stop dnstt
sudo systemctl disable dnstt

sudo rm -f /usr/local/bin/dnstt-server
sudo rm -f /usr/local/bin/dnstt

sudo rm -f /etc/systemd/system/dnstt.service
sudo rm -rf /etc/dnstt

sudo systemctl daemon-reload
```

> As regras de `iptables/ip6tables` adicionadas não são automaticamente revertidas.
> Ajuste manualmente se necessário ou reinicie as políticas de firewall do servidor.

---

## 📂 Estrutura de Arquivos

* Binário do servidor:
  `/usr/local/bin/dnstt-server`

* Script de gerenciamento:
  `/usr/local/bin/dnstt`

* Chaves do servidor:
  `/etc/dnstt/server.key`
  `/etc/dnstt/server.pub`

* Serviço systemd:
  `/etc/systemd/system/dnstt.service`

---

* Autor: **Alex Moura** (@alexdsgmoura)
* GitHub: `https://github.com/alexdsgmoura/dnstt`

---

Construído para facilitar a instalação e o gerenciamento de servidores DNSTT de forma simples, padronizada e automatizada.