-- Migração 001 — contas de usuário (login com e-mail e senha).
-- Para bancos criados antes desta versão. Bancos novos já recebem isto pelo schema.sql.
--   psql -U equilibra -d equilibra -f database/migracoes/001_contas.sql
-- Pode ser executada mais de uma vez sem erro.

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS email           VARCHAR(254) UNIQUE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS senha_hash      VARCHAR(255);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS conta_criada_em TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'conta_completa') THEN
        ALTER TABLE usuarios
            ADD CONSTRAINT conta_completa CHECK ((email IS NULL) = (senha_hash IS NULL));
    END IF;
END $$;
