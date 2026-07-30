# Referência de configuração

[English](../en/CONFIGURATION.md) | [Português](CONFIGURATION.md)

## Escopo

O projeto atual armazena os valores específicos do ambiente diretamente em `Source/install.ps1` e `Source/detect.ps1` antes da geração do pacote do Intune.

Como esses valores passam a fazer parte do `.intunewin`, qualquer mudança de configuração exige uma nova geração controlada do pacote e atualização da implantação.

## Valores obrigatórios

### Valores do instalador

Edite `Source/install.ps1`:

```powershell
$RustDeskServer   = 'rustdesk.exemplo.interno'
$RustDeskHbbsPort = '21116'
$RustDeskHbbrPort = '21117'
$RustDeskApiPort  = '21114'
$RustDeskKey      = 'CHAVE-PUBLICA-DO-SERVIDOR'
$OrganizationName = 'orgname'
```

### Valores da detecção

Edite `Source/detect.ps1`:

```powershell
$ExpectedHost     = 'rustdesk.exemplo.interno'
$OrganizationName = 'orgname'
```

`$ExpectedHost` deve corresponder a `$RustDeskServer`, e `$OrganizationName` deve ser igual nos dois scripts.

## Definição dos campos

| Campo | Utilizado por | Finalidade | Classificação |
|---|---|---|---|
| `$RustDeskServer` | Instalador | Hostname ou IP usado em HBBS, HBBR e API. | Metadado de infraestrutura interna. |
| `$RustDeskHbbsPort` | Instalador | Porta do serviço de rendezvous. | Metadado de rede interna. |
| `$RustDeskHbbrPort` | Instalador | Porta do serviço de relay. | Metadado de rede interna. |
| `$RustDeskApiPort` | Instalador | Porta do endpoint de API. | Metadado de rede interna. |
| `$RustDeskKey` | Instalador | Chave pública do servidor distribuída aos clientes. | Material público de autenticação; não é segredo, mas exige integridade. |
| `$OrganizationName` | Instalador e detecção | Define diretórios de logs e marker da organização. | Identificador da organização. |
| `$ExpectedHost` | Detecção | Texto esperado em um `RustDesk2.toml` de máquina. | Metadado de infraestrutura interna. |

## Chave pública e chave privada

`$RustDeskKey` deve conter a chave pública usada pelos clientes para identificar o servidor RustDesk.

Não inclua:

- chave privada do servidor;
- credenciais da API;
- credenciais administrativas;
- senhas de usuários;
- personal access tokens;
- certificados com chave privada.

Uma chave pública pode ser distribuída, mas sua integridade continua crítica. Substituí-la pode redirecionar a confiança dos clientes para outra identidade de servidor.

## Configuração RustDesk gerada

O instalador gera um documento TOML equivalente a:

```toml
rendezvous_server = 'rustdesk.exemplo.interno:21116'
nat_type = 1
serial = 0
unlock_pin = ''
trusted_devices = ''

[options]
av1-test = 'Y'
relay-server = 'rustdesk.exemplo.interno:21117'
custom-rendezvous-server = 'rustdesk.exemplo.interno:21116'
api-server = 'http://rustdesk.exemplo.interno:21114'
key = 'CHAVE-PUBLICA-DO-SERVIDOR'
```

O script atual grava a URL da API com `http://`. Avalie se a implantação selecionada do RustDesk suporta ou exige HTTPS ou se o caminho permanece restrito a uma rede interna protegida. Não exponha uma API de gerenciamento sem criptografia em redes não confiáveis.

## Destinos da configuração

O mesmo conteúdo é gravado em:

```text
C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\ProgramData\RustDesk\config\RustDesk2.toml
C:\Users\Default\AppData\Roaming\RustDesk\config\RustDesk2.toml
C:\Users\<perfil-existente>\AppData\Roaming\RustDesk\config\RustDesk2.toml
```

A lista de usuários existentes é obtida do Registro de perfis do Windows.

## Nome da organização

`$OrganizationName` deriva:

```text
C:\ProgramData\{OrganizationName}\IntuneLogs\RustDesk-Intune-Install.log
C:\ProgramData\{OrganizationName}\IntuneMarkers\RustDesk-Configured.marker
```

Use um nome curto, estável e seguro para caminhos do Windows.

Evite:

- separadores de caminho;
- espaços finais;
- caracteres reservados do Windows;
- nomes de clientes ou ambientes sensíveis em exemplos públicos;
- valores diferentes entre instalador e detecção.

Alterar o nome da organização muda o caminho esperado do marker. A detecção do Intune falhará até que o novo pacote conclua a instalação e gere o novo marker.

## Seleção do MSI

O instalador utiliza:

```powershell
Get-ChildItem -Path $PSScriptRoot -Filter '*.msi' | Select-Object -First 1
```

Portanto:

- mantenha apenas um MSI destinado à instalação em `Source/`;
- não mantenha versões antigas do MSI no mesmo diretório do pacote;
- registre nome, versão, assinatura e SHA-256 em cada release;
- gere um novo pacote sempre que o MSI mudar.

O arquivo não precisa tecnicamente se chamar `RustDesk.msi`, mas esse nome é recomendado para clareza.

## Propriedades de instalação do MSI

O instalador atual solicita:

| Propriedade | Valor |
|---|---|
| Interface | Silenciosa (`/qn`) |
| Reinicialização | Suprimida (`/norestart`) |
| Diretório | `%ProgramFiles(x86)%\RustDesk` |
| Atalho no menu Iniciar | Habilitado |
| Atalho na área de trabalho | Desabilitado |
| Impressora virtual | Desabilitada |
| Log MSI | Verbose |

Teste essas propriedades com a versão exata do MSI utilizada. Propriedades do pacote do fornecedor podem mudar entre versões.

## Bloco de senha permanente

O instalador contém um bloco opcional controlado por:

```powershell
$EnablePasswordConfig = $false
```

Mantenha desabilitado até que o desenho de credenciais tenha sido formalmente revisado.

Não:

- versione uma senha real no Git;
- distribua uma senha compartilhada em todos os endpoints;
- grave segredos no README, marker ou logs;
- considere o `.intunewin` como cofre de segredos;
- reutilize credenciais da equipe de suporte como credenciais dos endpoints.

Abordagens preferíveis incluem credenciais únicas por dispositivo, autorização governada pelo servidor, integração com identidade, acesso just-in-time e rotação auditada.

## Sincronização entre scripts

Antes de cada build, compare:

| Instalador | Detecção | Relação obrigatória |
|---|---|---|
| `$RustDeskServer` | `$ExpectedHost` | Mesmo valor. |
| `$OrganizationName` | `$OrganizationName` | Mesmo valor. |

Uma divergência pode causar:

- instalação bem-sucedida com detecção falhando;
- marker criado em caminho diferente do esperado;
- repetição da instalação pelo Intune;
- relatório de falha mesmo com o RustDesk em execução.

## Checklist de validação

Antes do empacotamento:

- [ ] Hostname ou endereço do servidor está correto.
- [ ] Porta HBBS está correta.
- [ ] Porta HBBR está correta.
- [ ] Porta e transporte da API foram aprovados.
- [ ] Chave pública corresponde ao servidor de destino.
- [ ] Nenhuma chave privada ou credencial está presente.
- [ ] Nome da organização é seguro e consistente.
- [ ] Host da detecção corresponde ao host do instalador.
- [ ] Existe apenas um MSI em `Source/`.
- [ ] Assinatura e hash do MSI foram verificados.
- [ ] Bloco de senha está desabilitado.
- [ ] Exemplos públicos foram sanitizados.

## Procedimento de mudança de configuração

1. documentar a alteração de infraestrutura solicitada;
2. atualizar os valores do instalador;
3. atualizar os valores correspondentes da detecção;
4. validar o MSI e o diretório de origem;
5. revisar manualmente o TOML gerado;
6. gerar um novo `.intunewin`;
7. atualizar versão e script de detecção no Intune;
8. implantar no grupo piloto;
9. validar logs, marker, serviço e conectividade;
10. expandir somente depois da estabilidade do piloto.

## Limitações conhecidas da configuração

- Valores são duplicados entre scripts em vez de lidos de um arquivo compartilhado.
- A detecção valida apenas o host, não todos os campos do TOML.
- O instalador grava a mesma configuração em todos os perfis encontrados.
- A configuração não é reconciliada continuamente após a instalação.
- A URL da API é gerada com `http://` no script atual.
- O bloco opcional de senha é baseado em script, não em cofre de segredos.

Essas limitações devem ser consideradas em uma futura etapa de hardening.

## Documentação relacionada

- [Arquitetura](ARCHITECTURE.md)
- [Implantação pelo Microsoft Intune](INTUNE.md)
- [Política de segurança](../../SECURITY.md)
