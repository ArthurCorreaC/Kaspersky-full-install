# 🛡️ Kaspersky-full-install

Scripts para **instalação automatizada do Kaspersky Endpoint Security** em máquinas Windows, com download automático do instalador, configuração via `.env` e registro completo de logs.

---

## 📁 Estrutura do Projeto

```
Kaspersky-full-install/
├── .env                     # Configuração de URL e servidores
├── instalar_admin.bat       # Inicializa o processo (executar como Administrador)
├── kaspersky_installer.ps1  # Lógica de instalação
├── cleaner/                 # Ferramenta de limpeza
└── kaspersky/               # Instalador offline (baixado automaticamente se faltar)
```

---

## ⚙️ Configuração (.env)
Edite o arquivo `.env` antes de executar. Valores padrão já estão preenchidos.

```
INSTALLER_URL=https://dados.3cta.eb.mil.br/s/cyJnnqEMn8pa3NP/download?path=%2FWindows&files=installer_win_12_11.exe  # URL do instalador oficial
MANAGEMENT_SERVER=ksc3cta02.3cta.eb.mil.br                                             # Servidor Kaspersky Security Center
NTP_SERVER=ntp.3cta.eb.mil.br                                                          # Servidor NTP
LOG_DIRECTORY=log                                                                      # Pasta para armazenar logs
PATCH_MODE=skip                                                                        # skip (padrão), prompt, ou auto
PAUSE_ON_EXIT=false                                                                    # true/1/yes para pausar; padrão totalmente automático
```

---

## 🚀 Como funciona
1. Execute `instalar_admin.bat` como administrador.
2. O `.bat` chama `kaspersky_installer.ps1`, que:
   - Garante permissão administrativa e codificação UTF-8.
   - Carrega as variáveis do `.env`.
   - Baixa o instalador para `kaspersky/installer.exe` (renomeado automaticamente) caso não exista localmente, priorizando **BITS** para uma transferência mais rápida e retomável (cai para `Invoke-WebRequest` se indisponível).
   - Executa o **cleaner** (quando necessário) e a instalação do Kaspersky.
   - Configura servidor de gerenciamento e NTP.
   - Registra todas as ações em `log/` (log resumido e transcript completo).

> Para evitar pausas inesperadas, os patches opcionais são ignorados por padrão (`PATCH_MODE=skip`).

---

## 🧩 Pré-requisitos
- Windows 10/11 ou Windows Server compatível
- Permissão administrativa local
- PowerShell 5.1 ou superior com execução habilitada:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
```

---

## ▶️ Modo de uso
```bash
git clone https://github.com/ArthurCorreaC/Kaspersky-full-install.git
cd Kaspersky-full-install
# Ajuste o arquivo .env conforme necessário
instalar_admin.bat  # Executar como Administrador
```

---

## 📝 Logs
- Gerados automaticamente em `log/` com timestamp no nome do arquivo.
- Incluem mensagens de status e erros capturados durante a execução, além de um transcript completo do console.

---

## 🆘 Troubleshooting
- Se o Windows bloquear arquivos: Propriedades → "Desbloquear".
- Se o PowerShell bloquear scripts:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
```

---

## 📜 Licença
Indique aqui a licença do projeto (MIT, GPLv3, etc.).

---

## 👨‍💻 Autor
Mantenedor: **2º Ten - Arthur Henrique Correa Costa [EsPCEx]**
