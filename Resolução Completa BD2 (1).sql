-- ============================================================================
-- COLÉGIO COTEMIG - DISCIPLINA: BD2
-- RESOLUÇÃO COMPLETA DA ATIVIDADE PREPARATÓRIA (QUESTÕES A ATÉ K)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- a) Crie uma view para retornar o NomeAluno, NomeDisciplina, ano, 
-- nomeSituacao, nomeDepartamento do banco de dados Cotemig.
-- ----------------------------------------------------------------------------
CREATE VIEW vw_historico_alunos AS
SELECT 
    a.nomeAluno,
    d.nomeDisciplina,
    ma.ano,
    s.nomeSituacao,
    dep.nomeDepartamento
FROM matricula_aluno ma
INNER JOIN aluno a ON ma.codigoAlunoMatricula = a.codigoAluno
INNER JOIN disciplina d ON ma.codigoDisciplinaMatricula = d.codigoDisciplina
INNER JOIN situacao s ON ma.situacaoMatricula = s.codigoSituacao
INNER JOIN departamento dep ON d.codigoDepartamentoDisciplina = dep.codigoDepartamento;


-- ----------------------------------------------------------------------------
-- b) Crie uma view para retornar a quantidade de alunos existente em cada ano 
-- por situação.
-- ----------------------------------------------------------------------------
CREATE VIEW vw_qtd_alunos_ano_situacao AS
SELECT 
    ma.ano,
    s.nomeSituacao,
    COUNT(DISTINCT ma.codigoAlunoMatricula) AS quantidade_alunos
FROM matricula_aluno ma
INNER JOIN situacao s ON ma.situacaoMatricula = s.codigoSituacao
GROUP BY ma.ano, s.nomeSituacao;


-- ----------------------------------------------------------------------------
-- c) Crie uma tabela baseada em uma consulta que irá retornar a quantidade de 
-- disciplinas existente por departamento.
-- ----------------------------------------------------------------------------
CREATE TABLE qtd_disciplinas_departamento AS
SELECT 
    dep.nomeDepartamento,
    COUNT(d.codigoDisciplina) AS quantidade_disciplinas
FROM departamento dep
LEFT JOIN disciplina d ON dep.codigoDepartamento = d.codigoDepartamentoDisciplina
GROUP BY dep.codigoDepartamento, dep.nomeDepartamento;


-- ----------------------------------------------------------------------------
-- d) Crie uma tabela chamada recuperacao com os campos:
-- i) codigoAlunoRecuperacao; ii) nota; iii) codigoDisciplinaRecuperacao;
-- ----------------------------------------------------------------------------
CREATE TABLE recuperacao (
    codigoAlunoRecuperacao INT NOT NULL,
    nota DECIMAL(5,2),
    codigoDisciplinaRecuperacao INT NOT NULL,
    PRIMARY KEY (codigoAlunoRecuperacao, codigoDisciplinaRecuperacao),
    FOREIGN KEY (codigoAlunoRecuperacao) REFERENCES aluno(codigoAluno),
    FOREIGN KEY (codigoDisciplinaRecuperacao) REFERENCES disciplina(codigoDisciplina)
);


-- ----------------------------------------------------------------------------
-- e) Crie uma tabela de log_recuperacao com os campos:
-- i) idLog - int; ii) descricao - text; iii) data - timestamp
-- ----------------------------------------------------------------------------
CREATE TABLE log_recuperacao (
    idLog INT AUTO_INCREMENT PRIMARY KEY,
    descricao TEXT,
    data TIMESTAMP
);


-- ----------------------------------------------------------------------------
-- f) Crie uma trigger de Insert para a tabela de recuperacao que irá disparar
-- "Antes" de inserir. Gravar: "Foi incluído na recuperação: Nome_Aluno - 
-- para a disciplina: Nome_disciplina" e a data/hora atual.
-- ----------------------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_before_insert_recuperacao
BEFORE INSERT ON recuperacao
FOR EACH ROW
BEGIN
    DECLARE v_nomeAluno VARCHAR(100);
    DECLARE v_nomeDisciplina VARCHAR(100);

    SELECT nomeAluno INTO v_nomeAluno 
    FROM aluno 
    WHERE codigoAluno = NEW.codigoAlunoRecuperacao;

    SELECT nomeDisciplina INTO v_nomeDisciplina 
    FROM disciplina 
    WHERE codigoDisciplina = NEW.codigoDisciplinaRecuperacao;

    INSERT INTO log_recuperacao (descricao, data)
    VALUES (
        CONCAT('Foi incluído na recuperação: ', v_nomeAluno, ' - para a disciplina: ', v_nomeDisciplina),
        CURRENT_TIMESTAMP()
    );
END //

DELIMITER ;


-- ----------------------------------------------------------------------------
-- g) Crie uma trigger de Update para a tabela de recuperacao que irá disparar
-- "Depois" que atualizar. Gravar: "Foi alterada a nota do aluno: Nome_Aluno - 
-- nota antiga: nota_antiga - nota nova: nota_nova" e a data/hora atual.
-- ----------------------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_after_update_recuperacao
AFTER UPDATE ON recuperacao
FOR EACH ROW
BEGIN
    DECLARE v_nomeAluno VARCHAR(100);

    SELECT nomeAluno INTO v_nomeAluno 
    FROM aluno 
    WHERE codigoAluno = NEW.codigoAlunoRecuperacao;

    INSERT INTO log_recuperacao (descricao, data)
    VALUES (
        CONCAT(
            'Foi alterada a nota do aluno: ', v_nomeAluno, 
            ' - nota antiga: ', IFNULL(OLD.nota, 'Sem nota'), 
            ' - nota nova: ', IFNULL(NEW.nota, 'Sem nota')
        ),
        CURRENT_TIMESTAMP()
    );
END //

DELIMITER ;


-- ----------------------------------------------------------------------------
-- h) Crie uma trigger de Delete para a tabela Matricula_aluno. Gravar:
-- "A disciplina: Nome_Disciplina - foi excluida" e a data/hora atual.
-- ----------------------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_after_delete_matricula
AFTER DELETE ON matricula_aluno
FOR EACH ROW
BEGIN
    DECLARE v_nomeDisciplina VARCHAR(100);

    SELECT nomeDisciplina INTO v_nomeDisciplina 
    FROM disciplina 
    WHERE codigoDisciplina = OLD.codigoDisciplinaMatricula;

    INSERT INTO log_recuperacao (descricao, data)
    VALUES (
        CONCAT('A disciplina: ', v_nomeDisciplina, ' - foi excluida'),
        CURRENT_TIMESTAMP()
    );
END //

DELIMITER ;


-- ----------------------------------------------------------------------------
-- i) Crie uma procedure que irá incluir os alunos que estão em recuperação na
-- tabela recuperacao utilizando cursor (seguindo os 11 passos).
-- ----------------------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE sp_incluir_alunos_recuperacao()
BEGIN
    -- 2. Crie uma variável para cada campo que sua consulta retornar
    DECLARE v_codigoAluno INT;
    DECLARE v_codigoDisciplina INT;
    DECLARE v_fim INT DEFAULT 0;

    -- 3. Inclua a consulta dentro de um cursor
    DECLARE cur_recuperacao CURSOR FOR
        SELECT ma.codigoAlunoMatricula, ma.codigoDisciplinaMatricula
        FROM matricula_aluno ma
        INNER JOIN situacao s ON ma.situacaoMatricula = s.codigoSituacao
        WHERE s.nomeSituacao LIKE '%Recuperação%';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;

    -- 4. Abra o cursor
    OPEN cur_recuperacao;

    -- 5. Inicie o loop
    l_loop: LOOP
        -- 6. Atribuir os dados do cursor para a variável (use o fetch)
        FETCH cur_recuperacao INTO v_codigoAluno, v_codigoDisciplina;

        -- 7. Valide se o cursor terminou. Se sim, saia do loop
        IF v_fim = 1 THEN
            LEAVE l_loop;
        END IF;

        -- 8. Para cada linha execute a inserção
        INSERT INTO recuperacao (codigoAlunoRecuperacao, nota, codigoDisciplinaRecuperacao)
        VALUES (v_codigoAluno, NULL, v_codigoDisciplina);

    -- 9. Feche o loop
    END LOOP l_loop;

    -- 10. Feche o cursor
    CLOSE cur_recuperacao;

-- 11. Finalize a procedure
END //

DELIMITER ;


-- ----------------------------------------------------------------------------
-- j) Crie uma função que avaliará se o aluno passou ou não.
-- ----------------------------------------------------------------------------
DELIMITER //

CREATE FUNCTION fn_avaliar_aluno(notaAluno DECIMAL(5,2))
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    DECLARE mensagem VARCHAR(100);

    IF notaAluno >= 60 THEN
        SET mensagem = 'Aprovado - Boas Férias';
    ELSE
        SET mensagem = 'Ainda há mais uma change! Bora estudar';
    END IF;

    RETURN mensagem;
END //

DELIMITER ;


-- ----------------------------------------------------------------------------
-- k) Crie uma procedure que irá fazer a exclusão na tabela Matricula_Aluno 
-- recebendo o Ano como parâmetro de entrada (sem valor fixo).
-- ----------------------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE sp_excluir_matriculas_por_ano(IN p_ano INT)
BEGIN
    DELETE FROM matricula_aluno 
    WHERE ano = p_ano;
END //

DELIMITER ;

-- Exemplo de chamada da procedure da questão k para o ano de 2022:
-- CALL sp_excluir_matriculas_por_ano(2022);