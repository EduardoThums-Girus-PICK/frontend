
# Desafio PICK Girus

O arquivo `Dockerfile` da aplicação criado como parte da resolução do primeiro desafio PICK da 2ª turma de 2024.

O objetivo era criar um imagem docker de uma aplicação em golang de forma otimizada, utilizando as melhores práticas de segurança e com o menor tamanho possível.

### Frontend (React)

O frontend do GIRUS proporciona uma interface web moderna e responsiva para interação com os laboratórios. Desenvolvido com React, TypeScript e Material-UI, ele apresenta um terminal interativo, instruções de tarefas, e feedback visual sobre o progresso.

#### Principais Recursos do Frontend

- **Terminal Interativo**: Implementado com xterm.js e conectado via WebSocket ao pod do laboratório
- **Painel de Tarefas**: Exibe instruções passo a passo e botões de validação
- **Navegação entre Tarefas**: Permite avançar e retroceder entre diferentes etapas do laboratório
- **Feedback Visual**: Indicadores de progresso e mensagens de validação
- **Seletor de Laboratórios**: Interface para escolher entre os diferentes laboratórios disponíveis

## Como buildar a imagem

Para buildar a imagem serão necessários os seguintes pré-requisitos:

- Docker

Siga o seguinte passo-a-passo:

1. Clone o repositório

```bash
git clone https://github.com/EduardoThums-Girus-PICK/frontend.git girus-frontend
cd girus-frontend
```

2. Execute o comando `docker image build` para buildar a imagem no seu local

```bash
docker image build -t girus-frontend .
```

3. Verifique que a imagem foi criada com o comando `inspect`

```bash
docker image inspect girus-frontend
```

## Como executar a imagem

A imagem do frontend pode ser executada diretamente no docker, porém é recomendado que ela seja executada dentro de um cluster kubernetes para habilitar a conectividade com o backend.

### Executando via docker

Ao executar a aplicação via docker não será possível criar os laboratórios já que a aplicação do backend roda apenas dentro de um ecossitema kubernetes. 

1. Crie o container docker

```bash
docker container run -d -p 8000:8080 --name girus-frontend eduardothums/girus:frontend-v1.0.8
```

2. Verifique que o container esta rodando

```bash
docker ps | grep girus-frontend
```

3. Acesse a aplicação do frontend rodando em http://localhost:8000

### Executando via kubectl

Para executar a aplicação via kubectl é recomendável executar primeiramente o backend, para isso veja a documentação de como o faze-lo [aqui](https://github.com/EduardoThums-Girus-PICK/backend?tab=readme-ov-file#como-executar-a-imagem). 

1. Aplique o manifesto que cria o `ConfigMap` com a configuração do nginx e `Pod` 

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  default.conf: |
    server {
        listen 8080;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        # Compressão
        gzip on;
        gzip_vary on;
        gzip_min_length 1000;
        gzip_proxied any;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        gzip_comp_level 6;
        
        # Cache para recursos estáticos
        location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
            expires 30d;
            add_header Cache-Control "public, no-transform";
        }
        
        # Redirecionar todas as requisições API para o backend
        location /api/ {
            proxy_pass http://girus-backend:8080/api/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
            proxy_request_buffering off;
        }
        
        # Configuração para WebSockets
        location /ws/ {
            proxy_pass http://girus-backend:8080/ws/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 86400;
        }
        
        # Configuração para React Router
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: girus-frontend
  labels:
    app: girus-frontend
spec:
  containers:
    - name: frontend
      image: eduardothums/girus:frontend-v1.0.8
      imagePullPolicy: IfNotPresent
      ports:
        - containerPort: 8080
      volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
  volumes:
    - name: nginx-config
      configMap:
        name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: girus-frontend
spec:
  selector:
    app: girus-frontend
  ports:
    - port: 8080
EOF
```

2. Aguarde até que o pod tenha inicializado

```bash
kubectl wait pod --all --for=condition=Ready -l app=girus-frontend --timeout 60s
```

3. Inspecione os logs do pod

```bash
kubectl logs girus-frontend
```

4. Faça um port-foward para ser possivel chamar o frontend através do localhost

```bash
kubectl port-forward services/girus-frontend 8000:8080
```

5. Acesse o frontend no endereço http://localhost:8000

## Como verificar a sua assinatura

Para verificar a autenticidade da imagem é possível utilizar o programa `cosign` utilizando a parte pública da chave utilizada para assinar a imagem.

```bash
cosign verify --key https://raw.githubusercontent.com/EduardoThums-Girus-PICK/cosign-pub-key/refs/heads/main/cosign.pub eduardothums/girus:frontend-v1.0.8
```

## Sobre a construção da imagem

Abaixo está o arquivo `Dockerfile` utilizado para buildar a imagem, foi utilizado a técnica de multi-stage build para otimizar o tamanho final das layers, abaixo será explicado o funcionamento de cada comando agrupados por stage.

```Dockerfile
# go:1.24.3
FROM cgr.dev/chainguard/go:latest@sha256:86afb531f453caf27580a0c7a11ac7f6c423cc1599a7ef53645e7353353ae302 AS healthcheck_builder

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go

# node:18.20.8
FROM cgr.dev/chainguard/node:latest@sha256:75e6c806a4654a59f42b957dcced700a25aa6c47c3fa3cfc37fed3cb9a86e5ac AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:8f363d198264b1b799704507065a7f9992ad330e40d6e30aff6a51cabfd0ee50

ARG revision
ARG version

LABEL \
  org.opencontainers.image.title="Girus Frontend" \
  org.opencontainers.image.description="Frontend for the Girus application" \
  org.opencontainers.image.authors="Eduardo Thums <eduardocristiano01@gmail.com>" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="$version" \
  org.opencontainers.image.url="https://linuxtips.io/girus-labs/" \
  org.opencontainers.image.source="https://github.com/EduardoThums-Girus-PICK/frontend" \
  org.opencontainers.image.documentation="https://github.com/EduardoThums-Girus-PICK/frontend/README.md" \
  org.opencontainers.image.revision="$revision"

COPY --from=healthcheck_builder /healthcheck /usr/local/bin/healthcheck
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=2s --timeout=5s --start-period=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]
```

### Stage de build do healthcheck

```Dockerfile
# go:1.24.3
FROM cgr.dev/chainguard/go:latest@sha256:86afb531f453caf27580a0c7a11ac7f6c423cc1599a7ef53645e7353353ae302 AS healthcheck_builder

COPY healthcheck.go .
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o healthcheck healthcheck.go
```

1. O comando `FROM` define a imagem base do stage `healthcheck_builder`, utilizamos a imagem do time da chainguard por não conter vulnerabilidades e ser mais segura de uma forma geral, além disso é utilizado o sha256 digest do repositório para garantir a integradade da versão caso haja uma atualização forçada.

2. Copiamos o script de healthcheck escrito em go com o comando `COPY`

3. Por fim compilamos o script de healthcheck com o comando `RUN go build` 

### Stage de build

```Dockerfile
# node:18.20.8
FROM cgr.dev/chainguard/node:latest@sha256:75e6c806a4654a59f42b957dcced700a25aa6c47c3fa3cfc37fed3cb9a86e5ac AS builder

WORKDIR /app

COPY package.json package-lock.json tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build
```

1. O comando `FROM` define a imagem base do stage `builder`, utilizamos a imagem `node` do time da chainguard por não conter vulnerabilidades e ser mais segura de uma forma geral, além disso é utilizado o sha256 digest do repositório para garantir a integradade da versão caso haja uma atualização forçada.

2. Os comandos `COPY package.json package-lock.json tsconfig.json ./` e `RUN npm ci` copiam os arquivos necessários e fazem o download das dependências do projeto, dessa forma caso haja alguma mudança no nosso código fonte, não será preciso re-buildar a layer novamente, otimizando o tempo de build e armazenamento das layers.

3. O comando `COPY . .` copia tudo do contexto de build atual para dentro da imagem, isso é possivel pois o nosso arquivo `.dockerignore` ignora tudo por padrão e libera apenas a cópia de arquivos especificos, precavendo a adição de arquivos futuros que não deveriam ir para a imagem.

4. Buildamos o projeto através do comando `RUN npm run build` que gera um diretório chamado `dist/` contendo os arquivos html, css e javascript otimizados.


### Stage final

```Dockerfile
# nginx:1.27.5
FROM cgr.dev/chainguard/nginx:latest@sha256:8f363d198264b1b799704507065a7f9992ad330e40d6e30aff6a51cabfd0ee50

ARG revision
ARG version

LABEL \
  org.opencontainers.image.title="Girus Frontend" \
  org.opencontainers.image.description="Frontend for the Girus application" \
  org.opencontainers.image.authors="Eduardo Thums <eduardocristiano01@gmail.com>" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="$version" \
  org.opencontainers.image.url="https://linuxtips.io/girus-labs/" \
  org.opencontainers.image.source="https://github.com/EduardoThums-Girus-PICK/frontend" \
  org.opencontainers.image.documentation="https://github.com/EduardoThums-Girus-PICK/frontend/README.md" \
  org.opencontainers.image.revision="$revision"

COPY --from=healthcheck_builder /healthcheck /usr/local/bin/healthcheck
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=2s --timeout=5s --start-period=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]
```

1. A imagem base utilizada é a `nginx` da chainguard, contendo apenas a aplicação nginx como executavel dentro dela.

2. Utilizamos o `ARG revision` e `ARG version` para passar por argumento no momento do build da imagem o sha256 do commit e tag para ser adicionado nas labels.

3. No `LABEL` adicionamos diversas labels com informações relevantes da imagem, como versão, autores, documentação, endereço do código fonte etc.

4. Copiamos o binario de healthcheck com stage `healthcheck_builder` com o comando `COPY`

5. Copiamos os conteudos do stage de build com o `COPY`.

6. Expomos a porta 8080 na image, default do nginx da chainguard.

7. Adicionamos um healthcheck inbutido na imagem com o comando `HEALTHCHECK`

8. Não há necessidade de sobreescrever o `ENTRYPOINT` da imagem do nginx.

## Fluxo do CI/CD

Utilizamos o GitHub Actions como plataforma de CI/CD do projeto, onde é realizado validações de segurança, boas práticas, build de imagems e publicações de releases através de tags do git.

Existem dois momentos onde os workflows definidos em `./github/workflows` são disparados:

1. `security_check.yaml`: quando há algum pull request aberto com a branch target apontando para a `main`
2. `release.yaml`: quando uma tag é criada no repositório

### security_check.yaml

Este workflow tem como objetivo:

1. Aplicar validações de segurança no código afim de encontrar vulnerabilidades de segurança nas dependências através da ferramenta [Trivy](https://trivy.dev/latest/)

2. Aplicar validações de segurança no build da imagem, afim de encontrar vulnerabilidades de segurança imagens base através da ferramenta [Trivy](https://trivy.dev/latest/)

3. Aplicar validações de boas práticas de criação de imagens com a ajuda do [Hadolint](https://github.com/hadolint/hadolint)

### release.yaml

Este workflow tem como objetivo:

1. Aplicar todas as etapas realizadas no workflow `security_check.yaml` para garantir que nenhuma vulnerabilidade veio a surgir entre o tempo de merge do pull request e a geração da tag

2. Buildar a imagem com a tag apontando para a tag do git

3. Fazer o push da imagem para o repositório no docker hub

4. Assinar a imagem utilizando o [Cosign](https://docs.sigstore.dev/cosign/)

5. Criar uma release com base na tag do git
