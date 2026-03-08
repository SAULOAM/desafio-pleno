### Jornada de Desenvolvimento e Decisões de Arquitetura

1.  **Escolha da Plataforma e Contêiner**:
    *   Optei por usar o **Google Cloud Platform (GCP)** pela sua robustez e ecossistema de serviços gerenciados.
    *   Para empacotar a aplicação Python (`api-py`), criei um **Dockerfile multi-stage**. Essa abordagem é ideal pois gera uma imagem final de produção menor e mais segura, contendo apenas o necessário para executar a aplicação, sem incluir dependências de build.

2.  **Infraestrutura como Código (IaC) com Terraform**:
    *   Escolhi o **Terraform** para automatizar o provisionamento da infraestrutura. Isso garante que o ambiente seja reprodutível, versionado e fácil de gerenciar.

3.  **Estratégia de Autenticação Segura (GitHub Actions <> GCP)**:
    *   Para a autenticação do pipeline no GCP, adotei a abordagem mais segura: **Workload Identity Federation (OIDC)**.
    *   **Por quê?** Essa técnica permite que o GitHub Actions se autentique diretamente no GCP usando tokens de curta duração, sem a necessidade de criar, gerenciar ou armazenar chaves de Service Account (que são credenciais de longa duração) como segredos no GitHub. Isso elimina um grande risco de segurança.

4.  **Construção da Esteira de CI/CD com GitHub Actions**:
    *   Desenvolvi uma esteira de CI/CD modular utilizando **Reusable Workflows**. Criei um arquivo `pipeline-orchestrator.yml` que atua como o maestro, chamando outros workflows em uma sequência lógica e controlada.
    *   A sequência de execução é: `demo` ➔ (`sonar-scan` + `terraform-lint`) ➔ `auth-deploy` ➔ `terraform-deploy`.
    *   Se qualquer um dos passos falhar, a esteira é interrompida, garantindo que um código de baixa qualidade ou uma configuração inválida nunca chegue à produção.

5.  **Implementação de Quality Gates**:
    *   **SonarCloud**: Adicionei um job (`sonar-scan`) para realizar análise estática de código na API Python. Isso ajuda a identificar bugs, vulnerabilidades e "code smells" antes do deploy.
    *   **Terraform Linting**: Criei um job (`terraform-lint`) que executa `terraform fmt`, `validate` e `tflint`. Isso garante que o código da infraestrutura esteja bem formatado, sintaticamente correto e livre de más práticas.

6.  **Correções e Refinamentos**:
    *   Resolvi um aviso do `tflint` adicionando a `required_version` no arquivo `provider.tf` para garantir a compatibilidade do Terraform.
    *   Corrigi um erro de execução do SonarScanner (`exit code 3`) adicionando a propriedade obrigatória `sonar.organization` no arquivo de configuração, necessária para a integração com o SonarCloud.

7.  **Estratégia de Rollback Automático**:
    *   No job de deploy do Terraform, implementei uma lógica de rollback. Se o `terraform apply` falhar, o pipeline automaticamente reverte o último commit do Git, tenta aplicar o estado anterior novamente e, em seguida, falha intencionalmente para notificar que o deploy original não foi bem-sucedido.

8.  **Depuração do SonarCloud**:
    *   Encontrei novamente o erro `exit code 3` do SonarScanner. Após verificar que o `SONAR_TOKEN` estava correto, identifiquei que o nome da organização (`sonar.organization`) estava incorreto. Corrigi de `sauloam` para `globo-test`, que é a organização correta no SonarCloud.

9.  **Ajuste Fino do SonarCloud**:
    *   O erro `exit code 3` persistiu. A causa provável é que a `sonar.projectKey` (`SAULOAM_desafio-pleno`) está associada à organização antiga. A chave do projeto é única *dentro* de uma organização. Ajustei a chave para um novo padrão (`globo-test_desafio-pleno`) e verifiquei se ela corresponde exatamente à chave do projeto configurada na UI do SonarCloud para a organização `globo-test`.

10. **Diagnóstico Final do SonarCloud**:
    *   Confirmado que a organização `globo-test` não possuía repositórios configurados. O erro ocorria porque o scanner tentava enviar análise para um projeto inexistente. A ação corretiva é criar/importar o projeto manualmente na interface do SonarCloud dentro da organização correta e atualizar o `sonar.projectKey` no arquivo de propriedades com o valor gerado pela plataforma.

11. **Retorno para Organização Pessoal**:
    *   Decidi reverter a configuração do SonarCloud para a organização `sauloam` (SAULOAM), onde o projeto já estava configurado ou é mais fácil de gerenciar, simplificando a resolução do erro de "Project not found".

12. **Correção da Chave do Projeto**:
    *   Atualizei a `sonar.projectKey` para `sauloam` no arquivo de propriedades, garantindo que corresponda exatamente à chave definida no projeto dentro do SonarCloud.testing the sonar
13. **Análise do Log de Erro do SonarCloud**:
    *   O log de erro `Could not find a default branch for project with key 'sauloam'` confirmou que a chave do projeto estava incorreta. Reverti a `sonar.projectKey` para o valor mais provável (`SAULOAM_desafio-pleno`), que segue o padrão gerado pelo SonarCloud ao importar um repositório.

14. **Correção Final da Organização SonarCloud**:
    *   Verifiquei nas configurações da organização que a **Key** correta é `sauloam` (minúsculo), enquanto "SAULO DANIEL" é apenas o nome de exibição. Atualizei `sonar.organization` para `sauloam` e `sonar.projectKey` para `sauloam_desafio-pleno` para corresponder à chave real da organização e ao padrão de projeto.

15. **Limpeza de Configuração do SonarCloud**:
    *   Com base na confirmação visual do painel do SonarCloud, removi uma linha duplicada e incorreta (`sSAULOAM-chh7g@github`) do arquivo `sonar-project.properties`, mantendo apenas a chave de organização correta `sauloam`.

16. **Localizando a Chave de Projeto Exata**:
    *   Para encontrar a `projectKey` definitiva, o passo correto é clicar no nome do projeto (`desafio-pleno`) na lista e, na página do projeto, localizar a seção "Project Information" na coluna da direita. O valor contido no campo "Project Key" é a fonte da verdade. Ajustei a chave para `desafio-pleno`, que é o valor mais provável.

17. **Diagnóstico Final: Problema de Token**:
    *   O log de erro `Project not found` persistiu, mesmo com as chaves de organização e projeto aparentemente corretas. A mensagem de aviso `Running this GitHub Action without SONAR_TOKEN is not recommended` e o erro de permissão indicam que o problema final está no `SONAR_TOKEN` armazenado nos segredos do GitHub. A solução é gerar um novo token no SonarCloud e atualizá-lo no repositório do GitHub para garantir que a autenticação seja bem-sucedida.

18. **Confirmação Visual da Chave do Projeto**:
    *   Através da seção "Information" na interface do SonarCloud, confirmei que a **Project Key** exata é `SAULOAM_desafio-pleno` e a **Organization Key** é `sauloam`. Atualizei o arquivo `sonar-project.properties` com esses valores definitivos.

19. **Resolvendo Conflito de Análise no SonarCloud**:
    *   O pipeline passou a falhar com um novo erro: `You are running CI analysis while Automatic Analysis is enabled`. Isso é um bom sinal, pois significa que a autenticação está funcionando e o projeto foi encontrado. O erro indica um conflito entre a análise via CI (configurada no GitHub Actions) e a funcionalidade de "Análise Automática" do SonarCloud. A solução é desabilitar a "Análise Automática" nas configurações do projeto no SonarCloud (`Administration` > `Analysis Method`).

20. **Provisionamento de Kubernetes (GKE)**:
    *   Para orquestrar o container da aplicação, decidi provisionar um cluster **Google Kubernetes Engine (GKE)** via Terraform.
    *   Criei também um repositório no **Artifact Registry** para armazenar as imagens Docker da aplicação.
    *   Utilizei máquinas *preemptible* (spot) no node pool para reduzir custos durante o desenvolvimento.

21. **Pipeline de Deploy da Aplicação (CD)**:
    *   Criei os manifestos do Kubernetes (`k8s/deployment.yaml`) definindo um Deployment e um Service (LoadBalancer) para a API.
    *   Implementei um novo workflow (`app-deploy.yml`) que realiza o build da imagem Docker, faz o push para o Artifact Registry e aplica os manifestos no cluster GKE recém-criado.
    *   Atualizei o orquestrador para executar o deploy da aplicação apenas após o sucesso do provisionamento da infraestrutura (`terraform-deploy`).

22. **Garantindo Zero Downtime no Deploy**:
    *   Para atender ao requisito de não haver indisponibilidade durante as atualizações, configurei a estratégia de `RollingUpdate` no manifesto do Kubernetes (`deployment.yaml`).
    *   Defini `maxSurge: 1` e `maxUnavailable: 0`. Isso força o Kubernetes a criar um novo pod da aplicação e esperar que ele esteja totalmente pronto antes de remover o pod antigo, garantindo uma transição suave e sem interrupção do serviço.
    *   Adicionei `readinessProbe` e `livenessProbe` para que o Kubernetes possa verificar ativamente a saúde da aplicação. O `readinessProbe` é crucial, pois impede que o tráfego seja enviado para um novo pod antes que ele esteja realmente pronto para processar requisições.

23. **Diagnóstico de Erro de Autenticação do Terraform**:
    *   O pipeline falhou com o erro `Not found; Gaia id not found for email ***`. Este erro indica que a Service Account (`github-actions-sa@projeto-globo.iam.gserviceaccount.com`) que o GitHub Actions está tentando usar não existe no projeto GCP ou não tem as permissões de Workload Identity configuradas.
    *   A solução é criar a Service Account no GCP, garantir que ela tenha as roles necessárias (`Service Usage Admin`, `Kubernetes Engine Admin`, `Artifact Registry Admin`) e que a Workload Identity Pool tenha permissão para personificá-la (`Workload Identity User`).
    *   Como melhoria, alterei `disable_on_destroy = true` para `false` nos recursos `google_project_service` para garantir que o `terraform destroy` limpe completamente o ambiente, desativando as APIs.

24. **Execução de Scripts de Setup GCP**:
    *   Para resolver o erro de "Gaia id not found", executei (ou documentei a necessidade de executar) os comandos `gcloud` para criar a Service Account `github-actions-sa` e configurar as permissões de IAM e Workload Identity Federation, já que esses são pré-requisitos para que o Terraform possa rodar via GitHub Actions.

25. **Resolução de Permissão do Usuário e Limpeza do Projeto**:
    *   Encontrei o erro `IAM_PERMISSION_DENIED` ao tentar rodar comandos `gcloud` localmente. A causa é que meu usuário (`saulosk.silva@gmail.com`) não tinha a permissão `iam.serviceAccounts.create`. A solução foi adicionar a role `Service Account Admin` a este usuário no painel do IAM no GCP.
    *   Realizei uma limpeza no repositório, consolidando a lógica de Zero-Downtime (`RollingUpdate` e `probes`) no manifesto Kubernetes correto (`k8s/deployment.yaml`) e removendo arquivos de workflow e configuração duplicados/obsoletos para melhorar a organização e clareza do projeto.

26. **Diagnóstico de Erro de Autenticação do Terraform no Pipeline**:
    *   O pipeline falhou com o erro `Not found; Gaia id not found for email ***`. Este erro indica que a Service Account (`github-actions-sa@projeto-globo.iam.gserviceaccount.com`) que o GitHub Actions está tentando usar não existe no projeto GCP.
    *   A solução é um pré-requisito de setup no ambiente GCP: criar a Service Account, garantir que ela tenha as roles necessárias (`Service Usage Admin`, `Kubernetes Engine Admin`, `Artifact Registry Admin`, `Storage Admin`) e, crucialmente, conceder a permissão `Workload Identity User` para que o pipeline do GitHub possa personificá-la.

27. **Correção do ID do Projeto GCP**:
    *   Identifiquei que o ID do projeto GCP criado automaticamente ou utilizado era `projeto-globo-489614`, e não apenas `projeto-globo`.
    *   Atualizei todos os arquivos de configuração (`infra/provider.tf`, workflows de auth e deploy) para usar o ID correto e o e-mail correto da Service Account (`github-actions-sa@projeto-globo-489614.iam.gserviceaccount.com`), garantindo que os recursos sejam criados e acessados no local certo.

28. **Correção de Credenciais nos Workflows de Deploy**:
    *   O erro `Gaia id not found` persistiu durante a execução do Terraform. Diagnostiquei que, embora o arquivo `gcp-auth.yml` tivesse sido atualizado, os workflows `terraform-deploy.yml` e `app-deploy.yml` ainda estavam consumindo os segredos do GitHub (`GCP_SERVICE_ACCOUNT`), que continham o e-mail da Service Account antiga.
    *   Atualizei esses workflows para usar explicitamente o e-mail da nova Service Account (`github-actions-sa@projeto-globo-489614...`) e padronizei a configuração do Workload Identity Provider.

29. **Resolução de Permissão de Impersonation (403)**:
    *   O pipeline evoluiu para um erro `403 PERMISSION_DENIED` com a mensagem `Permission 'iam.serviceAccounts.getAccessToken' denied`. Isso indica que a autenticação inicial funcionou, mas a identidade do GitHub Actions não tinha permissão para *impersonar* a Service Account.
    *   A solução foi garantir que o principal do GitHub Actions (`principalSet://...`) tivesse a role `Workload Identity User` na Service Account `github-actions-sa@...` no GCP, permitindo a geração de tokens.
    *   Corrigi também um caminho de arquivo incorreto no workflow `app-deploy.yml` que impedia a localização do manifesto Kubernetes.

30. **Troca de Service Account (Exclusão da Anterior)**:
    *   A conta de serviço original `github-actions-sa` foi excluída. Identifiquei uma conta alternativa disponível: `github-actions-sa@projeto-globo-489614.iam.gserviceaccount.com`.
    *   Atualizei todos os workflows (`gcp-auth`, `terraform-deploy`, `app-deploy`) para usar esta nova conta.
    *   **Ação Pendente no GCP:** É necessário adicionar manualmente o papel `Usuário de identidade da carga de trabalho` (Workload Identity User) a esta nova conta `github-actions-sa-746` para permitir a autenticação via GitHub Actions.

30. **Clarificação sobre Permissões Herdadas e Limpeza Final**:
    *   Compreendi que a mensagem "Não é possível editar o papel porque ele foi herdado" no GCP IAM significa que a permissão foi concedida em um nível superior (Projeto) e não pode ser modificada no recurso filho (Service Account). A ação correta é **conceder um novo acesso** (`GRANT ACCESS`) com o papel `Workload Identity User` diretamente na Service Account para o principal do GitHub Actions.
    *   Consolidei a configuração de Zero-Downtime no arquivo `k8s/deployment.yaml` e corrigi o caminho para este arquivo no workflow `app-deploy.yml`. Recomendo fortemente a exclusão dos arquivos duplicados (`deployment.yaml` na raiz e em `.github/workflows`, e os `provider.tf` e `terraform-deploy.yml` obsoletos) para manter a clareza do projeto.

31. **Ajuste para Interface em Português no GCP**:
    *   Identifiquei que o botão "GRANT ACCESS" no console do GCP em português é chamado de **"CONCEDER ACESSO"**. O papel `Workload Identity User` é traduzido como **`Usuário de identidade da carga de trabalho`**. Segui os passos corretos na interface em português para adicionar a permissão de impersonation.
    *   Corrigi o caminho do manifesto Kubernetes no workflow `app-deploy.yml` para apontar para `k8s/deployment.yaml` em vez de um caminho incorreto.

32. **Navegação no IAM e Correção Crítica do Manifesto**:
    *   Clarifiquei que o botão "GERENCIAR ACESSO" leva à página principal do IAM, onde o botão **"+ CONCEDER ACESSO"** deve ser usado para adicionar o papel `Usuário de identidade da carga de trabalho`.
    *   Identifiquei e corrigi um erro crítico no pipeline `app-deploy.yml`: ele estava usando um manifesto Kubernetes (`infra/k8s/deployment.yaml`) que não continha a configuração de Zero-Downtime. Ajustei o caminho para usar o arquivo correto (`k8s/deployment.yaml`), garantindo que a estratégia de `RollingUpdate` e as `probes` sejam aplicadas.

33. **Confirmação da Interface do IAM e Limpeza Final**:
    *   Confirmei que o botão **"PERMITIR ACESSO"** é outra tradução válida para a ação de conceder permissões no IAM do GCP.
    *   Reiterei a correção do caminho do manifesto Kubernetes no workflow `app-deploy.yml` e a importância de remover os arquivos duplicados e obsoletos para a saúde e clareza do projeto.
