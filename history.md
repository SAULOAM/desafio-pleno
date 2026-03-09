### Resumo da Arquitetura e Evolução do Projeto

Este documento narra a jornada de desenvolvimento de uma aplicação Python, desde sua concepção até um sistema robusto e automatizado na nuvem, destacando as principais decisões de arquitetura e os desafios superados.

---

#### 1. Fundações: Infraestrutura como Código e Segurança

*   **Provisionamento com Terraform**: Toda a infraestrutura foi definida como código utilizando **Terraform**. Isso garante um ambiente consistente, reprodutível e versionável. Os principais recursos provisionados foram:
    *   Um cluster **Google Kubernetes Engine (GKE)** para orquestrar os contêineres.
    *   Um repositório no **Artifact Registry** para armazenar as imagens Docker de forma segura.
    *   Service Accounts dedicadas com permissões refinadas, seguindo o princípio de menor privilégio.

*   **Segurança na Autenticação**: Para a comunicação entre o GitHub Actions e o Google Cloud, foi implementado o **Workload Identity Federation (OIDC)**. Esta é a abordagem mais segura e recomendada, pois elimina a necessidade de armazenar chaves de Service Account (credenciais de longa duração) como segredos no GitHub, utilizando em vez disso tokens de curta duração para autenticação.

#### 2. Automação e Qualidade: Pipeline de CI/CD

*   **Orquestração com GitHub Actions**: Foi construído um pipeline de CI/CD completo para automatizar o ciclo de vida da aplicação. A cada `push` na branch principal, o workflow é acionado para:
    1.  **Construir e Publicar a Imagem Docker**: A aplicação Python é empacotada em uma imagem Docker e enviada para o Artifact Registry com uma tag única (o hash do commit).
    2.  **Aplicar o Manifesto Kubernetes**: O pipeline se autentica no cluster GKE e aplica o `deployment.yaml`, atualizando a aplicação para a nova versão.

*   **Empacotamento Otimizado**: O `Dockerfile` foi projetado para ser eficiente, resultando em imagens pequenas e seguras, contendo apenas o necessário para a execução da aplicação em produção.

#### 3. Confiabilidade e Observabilidade

*   **Estratégia de Zero Downtime**: Para garantir que a aplicação nunca fique indisponível durante as atualizações, o `deployment.yaml` foi cuidadosamente configurado com:
    *   **`strategy: RollingUpdate`**: Com `maxSurge: 1` e `maxUnavailable: 0`, o Kubernetes é instruído a primeiro criar um novo pod da aplicação. Somente após o novo pod estar totalmente pronto, o antigo é removido, garantindo uma transição suave.
    *   **`readinessProbe` e `livenessProbe`**: Estas "sondas de saúde" são cruciais. A `readinessProbe` informa ao Kubernetes quando a aplicação está pronta para receber tráfego, e a `livenessProbe` verifica se a aplicação continua saudável, reiniciando-a automaticamente em caso de falha.

*   **Monitoramento com Prometheus e Grafana**: Para visibilidade completa do cluster e da aplicação, a stack **Prometheus + Grafana** foi implementada. A instalação foi automatizada via Terraform e Helm (`kube-prometheus-stack`), e o Grafana foi exposto com um LoadBalancer para fácil acesso aos dashboards de métricas.

#### 4. Desafios e Resoluções (Ciclo de Melhoria Contínua)

A jornada incluiu a superação de desafios técnicos que fortaleceram a arquitetura final:

*   **Permissões no GCP (IAM)**: Erros como `Gaia id not found` e `PERMISSION_DENIED` foram diagnosticados como problemas de configuração no IAM. A solução passou pela correta criação da Service Account e pela concessão do papel `Workload Identity User`, permitindo que o principal do GitHub Actions pudesse "personificar" a Service Account do GCP.

*   **Estabilização do Pod (`CrashLoopBackOff`)**: Este foi o desafio mais crítico. O pod da aplicação entrava em um loop de reinicialização. A análise com `kubectl describe pod` revelou a causa:
    1.  **Falha na `livenessProbe`**: A sonda HTTP falhava porque a rota de teste retornava 404 em uma aplicação recém-iniciada.
    2.  **Comando de Inicialização**: O `gunicorn` não era encontrado no `$PATH` do container.
    *   **Solução**: O manifesto foi ajustado para usar uma `tcpSocket` probe (que apenas verifica se a porta está aberta, sendo mais resiliente) e o comando de inicialização foi corrigido para `python -m gunicorn ...`, garantindo que o executável fosse encontrado no ambiente Python. Isso estabilizou o pod sem a necessidade de alterar o código da aplicação.

*   **Recursos do Cluster**: O erro `Insufficient cpu` foi resolvido ajustando o tipo de máquina dos nós do GKE para `e2-standard-2`, garantindo recursos suficientes para todos os componentes do sistema (Kubernetes, Prometheus, Grafana) e a aplicação rodarem sem contenção.
