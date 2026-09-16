-- =========================================================
-- Taller: Auditoría y Control de Usuarios mediante Triggers
-- Base de datos: personas
-- =========================================================

USE personas;

-- ---------------------------------------------------------
-- 4. Estructura de datos a implementar
-- ---------------------------------------------------------

-- Modificación de la tabla usuarios
ALTER TABLE usuarios ADD COLUMN correo VARCHAR(50) NULL;
ALTER TABLE usuarios ADD COLUMN saldo DECIMAL(10,2) NOT NULL DEFAULT 0.00;

-- Nueva tabla de auditoría
CREATE TABLE auditoria_usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT(2) NOT NULL,
  accion VARCHAR(10) NOT NULL,
  correo_anterior VARCHAR(50),
  correo_nuevo VARCHAR(50),
  saldo_anterior DECIMAL(10,2),
  saldo_nuevo DECIMAL(10,2),
  fecha_cambio DATETIME NOT NULL,
  usuario_bd VARCHAR(50)
);

-- ---------------------------------------------------------
-- 5.1 Trigger para auditoría de modificaciones (BEFORE UPDATE)
-- ---------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_auditar_update_usuario
BEFORE UPDATE ON usuarios
FOR EACH ROW
BEGIN
  IF NOT(OLD.correo <=> NEW.correo) OR NOT(OLD.saldo <=> NEW.saldo) THEN
    INSERT INTO auditoria_usuarios (id_usuario, accion, correo_anterior, correo_nuevo, saldo_anterior, saldo_nuevo, fecha_cambio, usuario_bd)
    VALUES (OLD.id, 'UPDATE', OLD.correo, NEW.correo, OLD.saldo, NEW.saldo, NOW(), USER());
  END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------
-- 5.2 Trigger para control de eliminación (BEFORE DELETE)
-- ---------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_controlar_eliminacion_usuario
BEFORE DELETE ON usuarios
FOR EACH ROW
BEGIN
  IF OLD.saldo > 500 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'No se puede eliminar un usuario con saldo superior a 500';
  END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------
-- 6. Casos de prueba y validación
-- ---------------------------------------------------------

-- Desactiva el modo "Safe Updates" de Workbench, que exige que el WHERE
-- use la llave primaria; aquí filtramos por nombre, no por id.
-- Se ejecuta una sola vez por sesión de conexión.
SET SQL_SAFE_UPDATES = 0;

-- 1. Insertar tres usuarios de prueba con diferentes saldos y correos
INSERT INTO usuarios (nombre, edad, correo, saldo) VALUES
('Carlos', 28, 'carlos@correo.com', 300.00),
('Laura', 34, 'laura@correo.com', 800.00),
('Pedro', 22, 'pedro@correo.com', 450.00);

-- 2. Actualización que modifica solo el correo (debe generar auditoría)
UPDATE usuarios SET correo = 'carlos.actualizado@correo.com' WHERE nombre = 'Carlos';

-- 3. Actualización que modifica solo el saldo (debe generar auditoría)
UPDATE usuarios SET saldo = 900.00 WHERE nombre = 'Laura';

-- 4. Actualización que modifica solo el nombre (NO debe generar auditoría)
UPDATE usuarios SET nombre = 'Miguel' WHERE nombre = 'Pedro';

-- 5. Intentar eliminar al usuario con saldo mayor a 500 (debe fallar con SIGNAL 45000)
DELETE FROM usuarios WHERE nombre = 'Laura';

-- 6. Intentar eliminar al usuario con saldo menor o igual a 500 (debe permitir)
DELETE FROM usuarios WHERE nombre = 'Carlos';

-- Verificación final
SELECT * FROM usuarios;
SELECT * FROM auditoria_usuarios;

-- ---------------------------------------------------------
-- 9. Actividad Bonus: borrado lógico (arqueo) de usuarios
-- ---------------------------------------------------------

-- Tabla para el arqueo/borrado lógico (misma estructura que usuarios)
CREATE TABLE usuarios_eliminados LIKE usuarios;

-- Trigger de archivo (AFTER DELETE)
DELIMITER $$
CREATE TRIGGER trg_archivar_usuario_eliminado
AFTER DELETE ON usuarios
FOR EACH ROW
BEGIN
  INSERT INTO usuarios_eliminados (id, edad, nombre, correo, saldo)
  SELECT OLD.id, OLD.edad, OLD.nombre, OLD.correo, OLD.saldo;
END$$
DELIMITER ;

-- Prueba del bonus: se usa un usuario nuevo porque Carlos ya se eliminó
-- en la prueba 6, antes de que existiera este trigger.
INSERT INTO usuarios (nombre, edad, correo, saldo) VALUES ('Ana', 26, 'ana@correo.com', 100.00);

-- Se elimina (pasa el trigger BEFORE DELETE porque su saldo es <= 500,
-- y dispara el AFTER DELETE que la archiva)
DELETE FROM usuarios WHERE nombre = 'Ana';

-- Verificación del bonus
SELECT * FROM usuarios;
SELECT * FROM usuarios_eliminados;
