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
