-- ---------------------------------------------------------------------
-- La cuenta donde viven los personajes MOLDE
-- ---------------------------------------------------------------------
-- MyAAC no inventa los personajes nuevos: COPIA uno que ya existe en la
-- base (system/src/CreateCharacter.php:124). Esos moldes los crea el
-- solo al terminar de instalarse (system/migrations/49.php), pero los
-- cuelga de la cuenta numero 1 sin fijarse si existe
-- (migrations/49.php:9, `getSession('account') ?? 1`).
--
-- En TVP la tabla players tiene una clave foranea contra accounts, asi
-- que si la cuenta 1 no existe el insert revienta y la instalacion se
-- corta a la mitad. Por eso hay que crearla ANTES.
--
-- La clave es basura a proposito (sha1 de la nada): esta cuenta no es
-- para entrar a jugar, solo para que los moldes tengan de donde colgar.
-- ---------------------------------------------------------------------

INSERT INTO `accounts` (`id`, `password`, `type`, `premium_ends_at`, `email`, `creation`, `failed_bid_count`)
VALUES (1, 'da39a3ee5e6b4b0d3255bfef95601890afd80709', 1, 0, '', 0, 0)
ON DUPLICATE KEY UPDATE `id` = `id`;
