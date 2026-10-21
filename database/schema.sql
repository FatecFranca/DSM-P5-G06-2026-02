-- Equilibra — esquema do banco PostgreSQL (16+)
-- Executado automaticamente pelo docker-compose na primeira subida do banco.
-- No Azure (PostgreSQL Flexible Server), rode este arquivo uma vez com psql.
--
-- Princípios (LGPD): nenhum nome, e-mail ou telefone é guardado. O usuário é
-- identificado por um UUID gerado no próprio aparelho. Ao apagar o usuário,
-- todas as avaliações dele são apagadas junto (ON DELETE CASCADE).

CREATE TABLE IF NOT EXISTS usuarios (
    id                UUID PRIMARY KEY,                       -- gerado no app
    consentimento_em  TIMESTAMPTZ NOT NULL,                   -- aceite do termo
    versao_termo      VARCHAR(10) NOT NULL DEFAULT '1.0',
    criado_em         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS avaliacoes (
    id                      BIGSERIAL PRIMARY KEY,
    usuario_id              UUID NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
    criado_em               TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Respostas do questionário (mesmos nomes do modelo de ML)
    area_curso              VARCHAR(20)  NOT NULL CHECK (area_curso IN ('exatas','negocios','humanas','saude','artes')),
    ano_curso               VARCHAR(20)  NOT NULL CHECK (ano_curso IN ('primeiro_ano','segundo_ano','terceiro_ano','quarto_ano','pos_graduacao')),
    nota_semestre_anterior  NUMERIC(4,2) NOT NULL CHECK (nota_semestre_anterior BETWEEN 0 AND 10),
    horas_ia_semana         NUMERIC(5,2) NOT NULL CHECK (horas_ia_semana BETWEEN 0 AND 80),
    horas_estudo_semana     NUMERIC(5,2) NOT NULL CHECK (horas_estudo_semana BETWEEN 0 AND 80),
    qtd_ferramentas_ia      SMALLINT     NOT NULL CHECK (qtd_ferramentas_ia BETWEEN 0 AND 10),
    dependencia_ia          SMALLINT     NOT NULL CHECK (dependencia_ia BETWEEN 1 AND 10),
    ansiedade_provas        SMALLINT     NOT NULL CHECK (ansiedade_provas BETWEEN 1 AND 10),
    assinatura_paga         BOOLEAN      NOT NULL,
    uso_principal_ia        VARCHAR(30)  NOT NULL CHECK (uso_principal_ia IN ('depurar_codigo','redigir_textos','gerar_ideias','resumir_leituras','respostas_prontas')),
    nivel_prompt            VARCHAR(20)  NOT NULL CHECK (nivel_prompt IN ('iniciante','intermediario','avancado')),
    politica_instituicao    VARCHAR(30)  NOT NULL CHECK (politica_instituicao IN ('proibido','permitido_com_citacao','incentivado')),

    -- Resultado da classificação
    nivel_risco             VARCHAR(10)  NOT NULL CHECK (nivel_risco IN ('baixo','medio','alto')),
    prob_baixo              NUMERIC(5,4) NOT NULL,
    prob_medio              NUMERIC(5,4) NOT NULL,
    prob_alto               NUMERIC(5,4) NOT NULL,
    versao_modelo           VARCHAR(60)  NOT NULL
);

-- Histórico do usuário é sempre lido do mais recente para o mais antigo.
CREATE INDEX IF NOT EXISTS ix_avaliacoes_usuario_data
    ON avaliacoes (usuario_id, criado_em DESC);
