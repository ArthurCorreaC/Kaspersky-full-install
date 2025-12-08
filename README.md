# 🛡️ Kaspersky-full-install

Este repositório contém um conjunto de scripts destinados à **instalação
automatizada do Kaspersky Endpoint Security** em máquinas Windows.\
O processo foi desenvolvido para facilitar a implantação em ambientes
corporativos, reduzindo intervenções manuais e garantindo padronização.

------------------------------------------------------------------------

## 📁 Estrutura do Projeto

    antivirus/
    │   instalar_admin.bat            # Script principal executado como administrador
    │   kaspersky_installer.ps1       # Script PowerShell responsável pela lógica da instalação
    │
    ├── cleaner/
    │       cleaner.exe               # Ferramenta de limpeza para remover instalações antigas
    │       kllibpq.dll               # Dependência da ferramenta de limpeza
    │       klmariadb.dll             # Dependência da ferramenta de limpeza
    │
    └── kaspersky/
            installer.exe             # Instalador offline/distribuição do Kaspersky

------------------------------------------------------------------------

## 🚀 Como funciona

1.  O usuário executa **`instalar_admin.bat`** como administrador.\
2.  O arquivo `.bat` chama o script **PowerShell**
    (`kaspersky_installer.ps1`).
3.  O script:
    -   verifica permissões;
    -   executa o **cleaner** para remover instalações anteriores (se
        necessário);
    -   dispara o instalador do Kaspersky;
    -   aplica parâmetros de configuração;
    -   valida a instalação.

------------------------------------------------------------------------

## 🧩 Pré-requisitos

-   Windows 10/11 ou Windows Server compatível\
-   Permissão administrativa local\
-   PowerShell 5.1 ou superior\
-   Execução de scripts habilitada

``` powershell
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
```

------------------------------------------------------------------------

## ▶️ Modo de uso

``` bash
git clone https://github.com/ArthurCorreaC/Kaspersky-full-install.git
cd kaspersky-installer/antivirus
instalar_admin.bat # executar como Administrador
```

------------------------------------------------------------------------

## 🧹 Diretório *cleaner/*

O **cleaner.exe** remove instalações antigas, chaves residuais e
serviços que podem impedir a nova instalação.

------------------------------------------------------------------------

## 🔧 Configurações internas

O `kaspersky_installer.ps1` controla todo o fluxo de instalação,
parâmetros, logs e validações.

------------------------------------------------------------------------

## 📝 Logs

Sugestão de boa prática: criar um diretório `logs/` e registrar
data/hora de instalação, versão, retorno do instalador, etc.

------------------------------------------------------------------------

## 🆘 Troubleshooting

### Instalador não inicia

-   Execute como administrador\
-   Se o Windows bloquear arquivos:
    -   Propriedades → "Desbloquear"

### PowerShell bloqueia scripts

``` powershell
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### Instalações antigas permanecem

O cleaner pode não ter sido acionado --- a lógica pode ser ajustada.

------------------------------------------------------------------------

## 📜 Licença

Indique sua licença (MIT, GPLv3, etc.)

------------------------------------------------------------------------

## 👨‍💻 Autor

Mantenedor: **2º Ten - Arthur Henrique Correa Costa [EsPCEx]**
