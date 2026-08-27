-- ---------------------------------------------------------------------
-- Cuenta de administrador de la WEB
-- ---------------------------------------------------------------------
-- MyAAC exige una clave de 8 a 30 caracteres con al menos una letra y un
-- numero (install/steps/7-finish.php). La cuenta 123456 del juego tiene
-- clave "123456", que no cumple, y en Tibia la clave de la web y la del
-- juego son LA MISMA (las dos salen de accounts.password). Cambiarsela a
-- la 123456 habria roto el login del cliente.
--
-- Por eso la web se administra con una cuenta aparte:
--     cuenta 100777 / clave tvp3d2026
--
-- La 123456 / 123456 queda intacta para jugar.
--
-- Tambien crea el personaje que MyAAC necesita para asociar al admin.
-- Los valores son los de un personaje recien hecho de Rookgaard,
-- copiados de servidor/docker/data/02-data.sql.
-- ---------------------------------------------------------------------

INSERT INTO `accounts` (`id`, `password`, `type`, `premium_ends_at`, `email`, `creation`, `failed_bid_count`)
VALUES (100777, 'e505251b84f88e5ce5756dc0254e90d3e20180be', 6, 2000000000, '', 0, 0)
ON DUPLICATE KEY UPDATE `password` = VALUES(`password`), `type` = VALUES(`type`);

INSERT INTO `players` (`name`, `group_id`, `account_id`, `level`, `vocation`, `health`, `healthmax`, `experience`,
                       `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `maglevel`, `mana`, `manamax`,
                       `manaspent`, `soul`, `town_id`, `posx`, `posy`, `posz`, `sex`, `lastlogin`, `lastip`, `skull`,
                       `skulltime`, `lastlogout`, `onlinetime`, `deletion`, `balance`, `stamina`, `skill_fist`,
                       `skill_fist_tries`, `skill_club`, `skill_club_tries`, `skill_sword`, `skill_sword_tries`,
                       `skill_axe`, `skill_axe_tries`, `skill_dist`, `skill_dist_tries`, `skill_shielding`,
                       `skill_shielding_tries`, `skill_fishing`, `skill_fishing_tries`)
SELECT 'Tvp Admin', 6, 100777, 1, 0, 150, 150, 0,
       0, 0, 0, 0, 128, 0, 0, 0,
       0, 100, 1, 32097, 32219, 7, 1, 0, 0, 0,
       0, 0, 0, 0, 0, 2520, 10,
       0, 10, 0, 10, 0,
       10, 0, 10, 0, 10,
       0, 10, 0
WHERE NOT EXISTS (SELECT 1 FROM `players` WHERE `name` = 'Tvp Admin');
