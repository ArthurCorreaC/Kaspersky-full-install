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
INSTALLER_URL=https://exemplo.com/installer.exe   # URL do instalador oficial
MANAGEMENT_SERVER=ksc3cta.3cta.eb.mil.br          # Servidor Kaspersky Security Center
NTP_SERVER=ntp.3cta.eb.mil.br                     # Servidor NTP
LOG_DIRECTORY=log                                 # Pasta para armazenar logs
```

---

## 🚀 Como funciona
1. Execute `instalar_admin.bat` como administrador.
2. O `.bat` chama `kaspersky_installer.ps1`, que:
   - Garante permissão administrativa e codificação UTF-8.
   - Carrega as variáveis do `.env`.
   - Baixa o `installer.exe` para `kaspersky/` caso não exista localmente.
   - Executa o **cleaner** (quando necessário) e a instalação do Kaspersky.
   - Configura servidor de gerenciamento e NTP.
   - Registra todas as ações em `log/`.

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
- Incluem mensagens de status e erros capturados durante a execução.

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
