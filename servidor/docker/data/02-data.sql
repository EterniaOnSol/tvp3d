-- account 123456/123456
INSERT INTO `accounts` (`id`, `password`, `type`, `premium_ends_at`, `email`, `creation`, `failed_bid_count`)
VALUES ('123456', '7c4a8d09ca3762af61e59520943dc26494f8941b', '6', '2000000000', 'no@example.com', '0', '0');

INSERT INTO `players` (`id`, `name`, `group_id`, `account_id`, `level`, `vocation`, `health`, `healthmax`, `experience`,
                       `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `maglevel`, `mana`, `manamax`,
                       `manaspent`, `soul`, `town_id`, `posx`, `posy`, `posz`, `sex`, `lastlogin`, `lastip`, `skull`,
                       `skulltime`, `lastlogout`, `onlinetime`, `deletion`, `balance`, `stamina`, `skill_fist`,
                       `skill_fist_tries`, `skill_club`, `skill_club_tries`, `skill_sword`, `skill_sword_tries`,
                       `skill_axe`, `skill_axe_tries`, `skill_dist`, `skill_dist_tries`, `skill_shielding`,
                       `skill_shielding_tries`, `skill_fishing`, `skill_fishing_tries`)
VALUES (NULL, 'GOD', '6', '123456', '100', '1', '50000', '50000', '0', '0', '0', '0', '0', '136', '10', '50000',
        '50000', '0', '0', '1', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '2520', '10', '0', '10',
        '0', '10', '0', '10', '0', '10', '0', '10', '0', '10', '0');
