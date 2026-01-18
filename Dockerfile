FROM public.ecr.aws/lambda/nodejs:20 AS nodebuild
WORKDIR /var/task
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

FROM public.ecr.aws/lambda/python:3.14
WORKDIR /var/task

# node だけあればOK（npm不要）
COPY --from=nodebuild /var/lang/bin/node /var/lang/bin/node

# MCPサーバの依存を同梱
COPY --from=nodebuild /var/task/node_modules /var/task/node_modules

# Python deps
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
ENV PATH="/var/lang/bin:${PATH}"
CMD ["app.lambda_handler"]
