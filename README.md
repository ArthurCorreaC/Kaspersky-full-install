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
AUTO_PATCH_STEP4=S                                                                     # Padrão "S" para aplicar o patch da Etapa 4 automaticamente ("1"/"true"/"yes"/"sim" também funcionam)
SILENT_INSTALL=1                                                                       # Padrão "1" para executar a instalação do antivírus em modo silencioso
INSTALLER_PARAMETERS=/pEULA=1 /pPRIVACYPOLICY=1 /pKSN=0 /pALLOWREBOOT=1 /s /qn         # Parâmetros passados ao instalador quando o modo silencioso está ativo
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

> 💡 Certificados HTTPS internos: o script ignora certificados inválidos ao baixar o instalador, para evitar falhas em redes internas. Os downloads continuam registrados em log.

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
